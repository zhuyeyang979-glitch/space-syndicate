extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const MAP_VIEW_SCRIPT_PATH := "res://scripts/map_view.gd"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const MONSTER_ART_SCRIPT_PATH := "res://scripts/monster_art_view.gd"
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")
const V06_RULES_SNAPSHOT := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")
const CARD_RESOLUTION_QUEUE_SCRIPT := preload("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
const RUNTIME_BALANCE_MODEL_SCRIPT := preload("res://scripts/balance/runtime_balance_model.gd")
const TEST_RUN_SAVE_PATH := "user://test_runs/smoke_test_current_run.save"
const SAVE_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const PRODUCT_MARKET_CONTROLLER_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController"
const SMOKE_PROGRESS_PATH := "user://space_syndicate_smoke_progress.log"
const EXPECTED_PLAYER_COUNT := 4
const EXPECTED_AI_PLAYER_COUNT := 3
const EXPECTED_SUMMONED_MONSTER_COUNT := 4
const MIN_REGION_COUNT := 6
const MAX_REGION_COUNT := 54

var _failures: Array[String] = []
var _smoke_start_msec := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_start_smoke_progress_log()
	_mark_smoke_progress("start")
	_cleanup_test_save()
	var packed := load(MAIN_SCENE_PATH)
	_mark_smoke_progress("main scene loaded")
	_expect(packed is PackedScene, "main scene loads as PackedScene")
	if not (packed is PackedScene):
		_finish()
		return

	var main := (packed as PackedScene).instantiate()
	_mark_smoke_progress("main scene instantiated")
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null and save_coordinator.has_method("set_qa_default_save_path_override") and bool(save_coordinator.call("set_qa_default_save_path_override", TEST_RUN_SAVE_PATH))
	_expect(save_override_ready, "smoke test installs an isolated QA save path before Main enters the tree")
	if not save_override_ready:
		main.free()
		_finish()
		return
	get_root().add_child(main)
	_mark_smoke_progress("main scene added")
	await process_frame
	_mark_smoke_progress("first process frame")
	await process_frame
	_mark_smoke_progress("second process frame")

	_expect(main is Control, "main scene instantiates as Control")
	var save_operation: Dictionary = save_coordinator.call("operation_snapshot")
	_expect(str(save_operation.get("default_save_path", "")) == TEST_RUN_SAVE_PATH and bool(save_operation.get("qa_save_path_override_active", false)), "Main and menu save queries use only the isolated QA save path")
	_mark_smoke_progress("isolated run save path active")
	var catalog_probe := int(main.call("_catalog_size"))
	_mark_smoke_progress("after catalog probe %d" % catalog_probe)
	_mark_smoke_progress("before open main menu")
	main.call("_open_main_menu")
	_mark_smoke_progress("main menu opened")
	await process_frame
	_mark_smoke_progress("main menu frame")
	var load_run_button := main.get("menu_load_run_button") as Button
	var run_save_label := _menu_overlay_node(main, "MenuRunSaveLabel") as Label
	_expect(run_save_label != null and run_save_label.text.contains("暂无"), "main menu reports no saved run in the test slot")
	_expect(load_run_button != null and load_run_button.disabled, "load run button is disabled when no test save exists")
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	_mark_smoke_progress("new game setup")
	main.call("_new_game")
	_expect(_verify_v06_market_rule_contract(), "smoke consumes the settled voluntary-summon and solar-market public rule contract")
	main.set("ai_card_decision_enabled", false)
	main.call("_open_main_menu")
	await process_frame
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	_expect(
		not main_source.contains("configured_monster_indices")
		and not main_source.contains("active_monster_indices")
		and not main_source.contains("SELECTED_MONSTER_COUNT")
		and not main_source.contains("_monster_lineup_start_districts"),
		"runtime removes the legacy four-monster lineup and compatibility state"
	)
	_expect(
		not main_source.contains("BALANCE_PRESETS")
		and not main_source.contains("current_balance_index")
		and not main_source.contains("_set_balance_preset")
		and not main_source.contains("_manual_settlement"),
		"runtime removes player-facing pacing presets and manual settlement debug hooks"
	)
	_expect(
		not main_source.contains("event_timer")
		and not main_source.contains("_world_event")
		and not main_source.contains("event_min")
		and not main_source.contains("星际商业新闻"),
		"news no longer fires as a passive world event; only player news cards can create news effects"
	)
	var legacy_detail_panel_terms := [
		"var setup" + "_box",
		"var district" + "_box",
		"var market" + "_box",
		"var combat" + "_box",
		"var log" + "_view",
		"_refresh_setup" + "_panel",
		"_refresh_district" + "_panel",
		"_refresh_market" + "_panel",
		"_refresh_combat" + "_panel",
		"_refresh_log" + "(",
		"_refresh_auto_monster" + "_panel",
		"_auto_monster_target_debug" + "_summary",
	]
	var has_no_legacy_detail_panel_source := true
	for legacy_term in legacy_detail_panel_terms:
		if main_source.contains(String(legacy_term)):
			has_no_legacy_detail_panel_source = false
			break
	_expect(has_no_legacy_detail_panel_source, "main play layout has no detached legacy detail/debug panel source")
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var skill_market := _as_array(main.get("skill_market"))
	var auto_monsters := _as_array(main.get("auto_monsters"))
	var product_market := _product_market_for_test(main)

	_expect(players.size() == EXPECTED_PLAYER_COUNT, "new game creates the configured player count")
	_expect(int(main.get("configured_ai_player_count")) == EXPECTED_AI_PLAYER_COUNT, "new game keeps the configured AI opponent count")
	_expect(_ai_player_count(players) == EXPECTED_AI_PLAYER_COUNT, "new game creates AI seats for the PVE roguelike run")
	_expect(not bool((players[0] as Dictionary).get("is_ai", true)) and bool((players[1] as Dictionary).get("is_ai", false)), "player 1 remains the human/local seat while later seats are AI opponents")
	_expect(((players[1] as Dictionary).get("ai_profile", {}) as Dictionary).has("style") and ((players[1] as Dictionary).get("ai_memory", {}) as Dictionary).has("decision_samples"), "AI seats carry a personality profile and training-memory log")
	var planet_profile := main.call("_roguelike_planet_profile") as Dictionary
	_expect(districts.size() >= int(planet_profile.get("region_min", MIN_REGION_COUNT)) and districts.size() <= int(planet_profile.get("region_max", MAX_REGION_COUNT)), "new game creates the expected roguelike region count")
	_expect(_regions_start_with_terrain_goods(main), "land and ocean regions start with one terrain-appropriate produced good and one demanded good before contracts expand them")
	_expect(auto_monsters.is_empty(), "new game starts with no field monsters until monster cards are played")
	_expect(_players_have_role_cards(main, players), "each player receives an alien syndicate role card")
	_expect(_role_catalog_has_positive_cards(main), "role codex exposes distinct alien cards through public balance and codex owners")
	_expect(_verify_random_ai_roles_resolve_unique(main), "random AI role setup resolves to public non-duplicate role cards")
	_expect(_verify_role_selection_and_budget_audit(main), "role setup resolves duplicate selections and every public role exposes balance-budget metadata")
	_expect(_role_cards_have_mechanical_passives(players), "role cards carry visible mechanical passive rules")
	_expect(_role_card_art_exposes_runtime_triggers(main), "role-card artwork exposes regional bonus-card, cashflow product cash, and monster-upgrade cash triggers")
	_expect(_verify_military_unit_variant_cards(main), "military card families cover air, land, ocean, terrain deployment, GDP pressure, route pressure, and distinct card facts")
	_expect(_verify_military_balance_identity(main), "military balance audit preserves fighter, bomber, tank, missile, submarine, and warship identities")
	_expect(_verify_ai_military_command_policy(main), "AI uses reusable military commands to guard cities, strike rivals, attack monsters, and record command metadata")
	_expect(_verify_ai_military_force_deploy_policy(main), "AI deploys military-force cards with field-driven guard, strike, and purchase metadata")
	_expect(_verify_product_futures_terms_catalog(main), "commodity futures use the complete v0.4 Inspector terms catalog with margin, caps, duration, and warehouse exposure")
	_expect(_verify_temporary_economy_duration_seconds(main), "temporary economy, contract, commodity, route, and derivative cards expose real seconds as their authoritative duration")
	_expect(_verify_role_passive_runtime(main), "role resource-cash, regional bonus-card, and monster-upgrade rewards resolve in play")
	_expect(_verify_ai_online_learning_policy(main), "AI opponents apply finalized money rewards as per-seat learned policy bonuses for future business, card, contract, and intel choices")
	_expect(_verify_ai_episode_learning_policy(main), "AI opponents backpropagate the versioned v0.5 victory receipt into per-seat long-horizon policy learning")
	_expect(_verify_role_intel_and_trace_tools(main), "identity roles and intel cards reveal private city, card-owner, and contract-party clues")
	_expect(_verify_ai_intel_policy(main), "AI opponents can use product clues to mark city owners and wager on anonymous card ownership")
	_expect(_verify_ai_monster_lure_strategy(main), "AI opponents can steer monster-lure cards toward high-value competing cities and record trainable target metadata")
	_expect(_verify_ai_economic_focus_strategy(main), "AI opponents maintain an economic focus product that shapes city expansion, economy-card targets, and training metadata")
	_expect(_verify_ai_strategy_intent_policy(main), "AI opponents switch between grow, defend, and disrupt strategic intents and attach strategy metadata to decisions")
	_expect(_verify_ai_route_plan_policy(main), "AI opponents form multi-step product-route plans that bias build, card, contract, and business choices")
	_expect(_verify_ai_game_phase_policy(main), "AI opponents adapt choices to opening, midgame, endgame, leader, and trailing states")
	_expect(_verify_ai_weather_control_policy(main), "AI opponents choose weather-control targets from route, terrain, GDP, and disruption value")
	_expect(_verify_ai_strategy_route_diversification_policy(main), "AI opponents generate field-driven defense, suppression, finance, and intel route candidates")
	_mark_smoke_progress("ai progress smoke")
	_expect(_verify_ai_progresses_run_smoke(main), "AI opponents can build, buy, earn income, and produce controller-readable victory progress without a mandatory opening card play")
	_mark_smoke_progress("max ai complete smoke")
	_expect(_verify_max_ai_seat_complete_smoke(main), "an eight-seat run with seven AI opponents can open, build, buy, play, report profile route actions, consume one victory receipt, and restore cleanly")
	_mark_smoke_progress("player table ui checks")
	_expect(_starting_cash_matches_role_bonuses(players), "role passives can modify the shared starting-cash baseline without touching starter monsters")
	_expect(int(main.call("_role_starting_cash_delta", {"starting_cash_delta": -150})) == -150 and int(main.call("_player_starting_cash_for_role", {"starting_cash_delta": -150})) == 1850, "role starting-cash modifiers can be positive or negative while the shared baseline remains intact")
	_expect(_starting_monster_cards_match_configured_choices(main, players), "starter monster cards come from independent setup choices, not role-card fingerprints")
	var player_box := main.get("player_box") as VBoxContainer
	var runtime_screen := main.get("runtime_game_screen") as Control
	var split_top_bar: Control = null
	var split_player_board: Control = null
	var split_resource_tableau: Control = null
	var split_hand_tableau: Control = null
	var split_command_tableau: Control = null
	var split_hand_rack: Control = null
	var split_hand_count_chip: Label = null
	var split_action_dock: Control = null
	var split_status_lamp_row: Control = null
	var split_readiness_chip_row: Control = null
	var split_right_inspector: Control = null
	if runtime_screen != null:
		split_top_bar = runtime_screen.find_child("TopBar", true, false) as Control
		split_player_board = runtime_screen.find_child("PlayerBoard", true, false) as Control
		split_resource_tableau = runtime_screen.find_child("PlayerResourceTableau", true, false) as Control
		split_hand_tableau = runtime_screen.find_child("PlayerHandTableau", true, false) as Control
		split_command_tableau = runtime_screen.find_child("PlayerCommandTableau", true, false) as Control
		split_hand_rack = runtime_screen.find_child("HandRack", true, false) as Control
		split_hand_count_chip = runtime_screen.find_child("PlayerHandCountChip", true, false) as Label
		split_action_dock = runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
		split_status_lamp_row = runtime_screen.find_child("PlayerStatusLampRow", true, false) as Control
		split_readiness_chip_row = runtime_screen.find_child("PlayerReadinessChipRow", true, false) as Control
		split_right_inspector = runtime_screen.find_child("RightInspector", true, false) as Control
	var split_first_hand_card := _first_control_child(split_hand_rack)
	var split_first_hand_card_data: Dictionary = {}
	if split_first_hand_card != null and split_first_hand_card.has_method("get_card_data"):
		var split_card_data_variant: Variant = split_first_hand_card.call("get_card_data")
		if split_card_data_variant is Dictionary:
			split_first_hand_card_data = split_card_data_variant
	var split_hand_targets: Array = []
	if split_hand_rack != null and split_hand_rack.has_method("get_card_target_snapshot"):
		var split_hand_targets_variant: Variant = split_hand_rack.call("get_card_target_snapshot")
		if split_hand_targets_variant is Array:
			split_hand_targets = split_hand_targets_variant
	_expect(_container_has_named_node(main, "PlaytestFlowCompass") and _container_label_text_contains(main, "试玩") and _container_label_text_contains(main, "罗盘") and _container_label_text_contains(main, "点区") and _container_label_text_contains(main, "买牌") and _container_label_text_contains(main, "出牌") and _container_label_text_contains(main, "牌轨") and _container_label_text_contains(main, "经济") and _container_label_text_contains(main, "路线"), "main planet board exposes a non-blocking first-run playtest flow through route choice beside the map")
	_expect(_container_has_named_node(main, "CardResolutionTimelineEventSlot") and _container_has_named_node(main, "TimelineEventReadOnlyBadge") and not _container_has_named_node(main, "RecentTableEventBar"), "top card-history timeline also carries read-only public events instead of a separate recent-event bar")
	_expect(
		(player_box != null and _container_label_text_contains(player_box, "我的手牌") and _container_label_text_contains(player_box, "资金:"))
		or (split_player_board != null and split_hand_rack != null and split_resource_tableau != null and _container_label_text_contains(split_resource_tableau, "现金") and split_hand_count_chip != null and split_hand_count_chip.text.contains("手牌")),
		"player panel keeps the main game view focused on hand cards and compact cash"
	)
	_expect(
		(player_box != null and _container_label_text_contains(player_box, "玩家板｜资源筹码") and _container_label_text_contains(player_box, "GDP") and _container_label_text_contains(player_box, "终局"))
		or (split_resource_tableau != null and _container_label_text_contains(split_resource_tableau, "现金") and _container_label_text_contains(split_resource_tableau, "GDP") and _container_label_text_contains(split_resource_tableau, "目标")),
		"player panel exposes a Terraforming-Mars-style resource chip tableau before detailed hand text"
	)
	_expect((player_box != null and _container_label_text_contains(player_box, "状态：") and (
		_container_label_text_contains(player_box, "可打出")
		or _container_label_text_contains(player_box, "需商品")
		or _container_label_text_contains(player_box, "需怪兽目标")
		or _container_label_text_contains(player_box, "需玩家目标")
		or _container_label_text_contains(player_box, "冷却中")
		or _container_label_text_contains(player_box, "需补牌")
	)) or (split_status_lamp_row != null and split_readiness_chip_row != null and _container_label_text_contains(split_readiness_chip_row, "手牌")), "hand cards show a board-game style playability state instead of a blind play button")
	_expect(
		(player_box != null and _container_has_named_node(player_box, "CardFaceRouteBand") and _container_has_named_node(player_box, "CardFaceRouteColorTick") and _container_has_named_node(player_box, "CardFaceQuickEffect") and _container_label_text_contains(player_box, "路线:") and _container_label_text_contains(player_box, "效果:"))
		or (split_first_hand_card != null and split_first_hand_card.name.begins_with("MiniHandCardFace") and split_first_hand_card_data.get("presentation") == "mini_hand" and split_first_hand_card_data.get("detail_policy") == "right_inspector"),
		"hand card faces expose a scan-first route band and one-line effect before cost and long rules text"
	)
	_expect(
		(player_box != null and _container_has_named_node(player_box, "HandCardHoverLiftCard") and _container_label_text_contains(player_box, "悬停抬起"))
		or (split_hand_rack != null and split_hand_rack.has_method("get_card_target_snapshot") and not split_hand_targets.is_empty()),
		"hand cards expose UiCard-style hover lift affordance"
	)
	_expect(
		(player_box != null and _container_button_tooltip_contains(player_box, "打出条件："))
		or (split_action_dock != null and _container_button_text_contains(split_action_dock, "出牌") and _container_button_tooltip_contains(split_action_dock, "手牌")),
		"hand card action buttons expose concise play requirements"
	)
	_expect(
		(player_box != null and _container_label_text_contains(player_box, "公开席位") and _container_has_named_node(player_box, "PlayerSeatCard") and _container_has_named_node(player_box, "PlayerSeatPublicChipRail") and _container_has_named_node(player_box, "PlayerSeatInspectorCard") and _container_label_text_contains(player_box, "明怪") and _container_button_tooltip_contains(player_box, "现金、手牌和弃牌不公开"))
		or (runtime_screen != null and split_top_bar != null and split_player_board != null and _container_label_text_contains(split_top_bar, "本席") and _container_label_text_contains(split_player_board, "本席") and not _container_label_text_contains(runtime_screen, "对手现金") and not _container_label_text_contains(runtime_screen, "私密计划")),
		"player panel exposes public-seat context without leaking private hands or cash"
	)
	if _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size() > 1:
		var presentation_coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
		var presentation_query := presentation_coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery if presentation_coordinator != null else null
		var viewer_snapshot := presentation_query.compose_table_state(0, true) if presentation_query != null else {}
		_expect(
			presentation_coordinator != null
			and int(presentation_coordinator.table_selection_state().selected_player) == 0
			and viewer_snapshot.get("player_board", {}) is Dictionary
			and not viewer_snapshot.has("players")
			and not viewer_snapshot.has("districts")
			and not viewer_snapshot.has("pending_contract_offers"),
			"runtime player snapshot keeps the local hand/action player stable without exposing private opponent fields"
		)
	_expect(
		(player_box != null and _container_label_text_contains(player_box, "目标提示") and _container_label_text_contains(player_box, "◎下一步") and _container_has_named_node(player_box, "TableGoalPrompt") and _container_has_named_node(player_box, "TableGoalPromptChipRail") and _container_has_named_node(player_box, "TableGoalConditionRail") and (_container_label_text_contains(player_box, "牌架") or _container_label_text_contains(player_box, "选区")))
		or (split_player_board != null and _container_label_text_contains(split_player_board, "下一步") and _container_label_text_contains(split_player_board, "选区")),
		"player panel shows one concise table-goal next-action card with scan-first condition chips"
	)
	_expect(
		(player_box != null and _container_has_named_node(player_box, "PlayerDashboardActionDock") and _container_has_named_node(player_box, "MainActionDock") and _container_has_named_node(player_box, "ActionDockReadinessChipRail") and _container_has_named_node(player_box, "PlayerDashboardPrimaryActionStrip") and _container_has_named_node(player_box, "PlayerDashboardPrimaryActionButton") and _container_has_named_node(player_box, "PlayerTableStateLampRail") and _container_label_text_contains(player_box, "桌边") and _container_label_text_contains(player_box, "推荐") and _container_label_text_contains(player_box, "桌态") and _container_label_text_contains(player_box, "本席") and _container_label_text_contains(player_box, "牌队") and _container_label_text_contains(player_box, "选区") and (_container_label_text_contains(player_box, "手牌") or _container_label_text_contains(player_box, "满手")) and _container_button_text_contains(player_box, "建城") and _container_button_text_contains(player_box, "牌架") and _container_button_text_contains(player_box, "买牌") and _container_button_text_contains(player_box, "出牌"))
		or (split_player_board != null and split_action_dock != null and split_status_lamp_row != null and split_readiness_chip_row != null and split_hand_count_chip != null and _container_label_text_contains(split_player_board, "本席") and _container_label_text_contains(split_player_board, "选区") and _container_label_text_contains(split_player_board, "手牌") and _container_button_text_contains(split_action_dock, "建城") and _container_button_text_contains(split_action_dock, "牌架") and _container_button_text_contains(split_action_dock, "买牌") and _container_button_text_contains(split_action_dock, "出牌")),
		"player panel exposes a first-screen dashboard action dock, recommended primary action, table-state lamps, readiness chips, and the detailed quick action tray for build, market, buy, and play"
	)
	_expect(
		(player_box != null and _container_has_named_node(player_box, "PlayerDashboardDistrictSummary") and _container_label_text_contains(player_box, "选区｜"))
		or (split_player_board != null and _container_label_text_contains(split_player_board, "选区")),
		"player panel keeps the selected district summary beside first-screen actions"
	)
	_expect(
		(player_box != null and _container_label_text_contains(player_box, "选区行动") and _container_label_text_contains(player_box, "牌架") and _container_label_text_contains(player_box, "HP") and _container_button_text_contains(player_box, "查看牌") and _container_button_text_contains(player_box, "商路"))
		or (split_player_board != null and split_action_dock != null and _container_label_text_contains(split_player_board, "选区") and _container_button_text_contains(split_action_dock, "建城") and _container_button_text_contains(split_action_dock, "牌架") and _container_button_text_contains(split_action_dock, "买牌")),
		"player panel exposes a chip-based selected-region action card"
	)
	_expect(split_top_bar != null and _container_button_text_contains(split_top_bar, "菜单"), "normal table keeps menu access without legacy onboarding overlays")
	_expect(
		(player_box != null and not _container_label_text_contains(player_box, "角色卡") and not _container_label_text_contains(player_box, "经济流水") and not _container_card_art_kind_contains(player_box, "player_role"))
		or (runtime_screen != null and not _container_label_text_contains(runtime_screen, "角色卡") and not _container_label_text_contains(runtime_screen, "经济流水") and not _container_card_art_kind_contains(runtime_screen, "player_role")),
		"player panel hides role/economy details from the main play screen"
	)
	_expect(_players_have_starting_monster_cards(main, players), "each player starts with a free first monster card")
	var first_starting_card := ((_as_array((players[0] as Dictionary).get("slots", [])))[0]) as Dictionary
	_expect(String(first_starting_card.get("summon_access", "")) == "any", "the starter monster card explicitly has no region restriction")
	_expect(String(main.call("_monster_card_region_text", first_starting_card)).contains("起始怪兽牌"), "starter card rules visibly say that its summon region is unrestricted")
	var regular_monster_card := main.call("_make_skill", String(first_starting_card.get("name", main.call("_monster_card_name", 0, 1)))) as Dictionary
	_expect(int(regular_monster_card.get("hp", 0)) > 0 and float(regular_monster_card.get("duration", 0.0)) > 0.0 and float(regular_monster_card.get("move", 0.0)) > 0.0, "monster cards carry HP, field duration, and movement attributes")
	_expect(String(first_starting_card.get("role_passive_summary", "")) == "" and is_equal_approx(float(first_starting_card.get("move", 0.0)), float(regular_monster_card.get("move", 0.0))), "role passives do not modify starter monster movement or expose ownership fingerprints")
	var fourth_starter := ((_as_array((players[3] as Dictionary).get("slots", [])))[0]) as Dictionary
	_expect(int(fourth_starter.get("fixed_skill_count", 0)) == int((main.call("_make_skill", String(fourth_starter.get("name", ""))) as Dictionary).get("fixed_skill_count", 0)), "role passives do not increase starter monster bound-skill count")
	_expect(String(regular_monster_card.get("summon_access", "")).ends_with("monster_zone"), "post-start monster cards carry a landed-or-adjacent monster-zone summon restriction")
	var regular_monster_art_stats := _card_presentation_text(main, regular_monster_card, "art_stats")
	_expect(regular_monster_art_stats.contains("HP") and regular_monster_art_stats.contains("怪区"), "monster-card artwork prints HP, duration, movement, and region access")
	_expect(_all_monster_cards_have_field_attributes(main), "every monster card rank defines HP, movement, duration, and summon-region attributes")
	_expect(_verify_monster_catalog_public_probability_contract(main, 0), "rank-IV monster catalog exposes public I/IV action probability progression without raw weights")
	_expect(_verify_monster_ecology_balance_audit(main), "monster ecology balance audit preserves movement, resources, actions, bound skills, and art identities")
	var regular_summon_rejected := not bool(_monster_controller(main).call("_summon_monster_from_card", players[0] as Dictionary, regular_monster_card))
	_expect(regular_summon_rejected and _as_array(main.get("auto_monsters")).is_empty(), "post-start monster cards cannot summon outside a landed or adjacent monster region")
	_expect(_verify_monster_card_terrain_restriction(main, players, districts), "terrain-restricted monster cards reject the wrong land/ocean district even inside a monster zone")
	_expect(not skill_market.is_empty(), "new game creates a card/skill market")
	_expect(product_market != null and not product_market.is_empty() and _product_market_has_prices(product_market), "new game creates priced product market data")
	var status_label := main.get("status_label") as Label
	_expect(status_label != null and status_label.text.contains("天气:") and status_label.text.contains("预报:"), "top status bar exposes active weather and the next public forecast")
	var weather_forecast_strip := main.find_child("WeatherForecastStrip", true, false) as Control
	var weather_layer := main.find_child("WeatherLayer", true, false) as Control
	if weather_layer == null:
		weather_layer = main.find_child("WeatherMapOverlay", true, false) as Control
	_expect(
		weather_forecast_strip != null
		and weather_forecast_strip.has_method("set_view_model")
		and weather_layer != null
		and weather_layer.has_method("set_overlay_view_model"),
		"main map panel exposes WeatherForecastStrip plus a weather layer instead of legacy label-only forecast UI"
	)
	_expect(_verify_weather_forecast_system(main), "planet weather forecasts use v1 timings: one region per event, 30-60s forecast, 45-90s active, 10s fade, max two unended events")
	_expect(_verify_news_and_weather_card_rules(main), "news cards are player-made effects while weather-control cards schedule explicit v1 public weather events")
	_summon_starting_monsters_for_smoke(main, EXPECTED_SUMMONED_MONSTER_COUNT)
	await process_frame
	_mark_smoke_progress("field monster checks")
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	skill_market = _as_array(main.get("skill_market"))
	auto_monsters = _as_array(main.get("auto_monsters"))
	product_market = _product_market_for_test(main)
	_expect(auto_monsters.size() == EXPECTED_SUMMONED_MONSTER_COUNT, "playing starting monster cards summons four anonymous automatic monsters for the smoke run")
	player_box = main.get("player_box") as VBoxContainer
	_expect(_summoned_monsters_have_hidden_owners(auto_monsters), "summoned monster ownership starts hidden while HP and duration are visible")
	_expect(_verify_monster_owner_damage_cash_clue(main), "monster damage cash clues reveal ownership with max-HP proportional losses")
	var first_actor := auto_monsters[0] as Dictionary
	_expect(int(first_actor.get("max_hp", 0)) == int(first_starting_card.get("hp", -1)) and is_equal_approx(float(first_actor.get("duration", 0.0)), float(first_starting_card.get("duration", -1.0))), "starter monster card HP and duration become the summoned monster's field attributes without role overrides")
	_expect(_verify_monster_card_runtime_overrides(main), "summoned monsters read HP, duration, and movement directly from their played card")
	_expect(_verify_field_monster_card_upgrade_refreshes_state(main), "same-name monster cards upgrade an owned field monster and refresh HP, duration, and damage-cash risk")
	_expect(_verify_single_owned_monster_limit_and_rank_iv_refresh(main), "one-player monster cap blocks new monsters but allows same-name rank-IV refresh")
	_expect(_verify_monster_duration_expiry(main), "a monster automatically leaves when its card field duration expires")
	_expect(_verify_monster_card_play_cash_cost(main), "monster-card play cash cost scales with field monster count and records card spend")
	_expect(_verify_ranked_monster_public_action_probabilities(main, first_actor), "summoned higher-rank monsters use public rank-tilted auto-action probabilities")
	_expect(_player_has_bound_monster_skill(players, 0), "summoning a monster grants its owner a persistent bound skill card")
	_expect(_player_bound_monster_skill_count(players, 3) >= 1, "summoning grants printed bound monster skills without role-based starter boosts")
	_expect(_verify_bound_monster_skill_persistence(main), "bound monster skills stay in hand and enter cooldown after use")
	_expect(_verify_monster_lure_replaces_control_window(main), "monster lure cards replace old control-window cards with one-shot anonymous movement guidance")
	_expect(_verify_anonymous_cash_card(main), "cash-card public events hide the player who played the card")
	_expect(_verify_anonymous_direct_command(main), "one-shot monster-command events hide the directing player")
	_mark_smoke_progress("v0.6 card resolution owner smoke")
	var queue_results := _verify_card_resolution_v06_owner_contracts(main)
	_expect(bool(queue_results.get("cadence", false)), "card windows use the v0.6 opening and standard planning/public/lock cadence")
	_expect(bool(queue_results.get("submission_limits", false)), "ordinary card groups allow one submission and reject new cards after planning")
	_expect(bool(queue_results.get("rotating_order", false)), "locked card groups resolve by rotating seat priority rather than retired cash bids")
	_expect(bool(queue_results.get("public_snapshot_safe", false)), "public card queue snapshots stay anonymous and contain no private bid metadata")
	_expect(bool(queue_results.get("lifecycle", false)), "the queue locks, starts, and completes one unique resolution without mutating Main state")
	_expect(bool(queue_results.get("owner_boundary", false)), "the queue owns no cash, inventory, or priority-bid authority")
	_expect(_verify_monster_takeover_resets_owner_clues(main), "monster takeover revokes old bound skills and resets cash clues to the new owner")
	_expect(_economy_ledgers_respect_active_view(main), "economy overview keeps other players' detailed ledgers private")
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	_expect(_product_market_float(product_market, "环晶电池", "growth_multiplier") >= 1.3, "流星哨兵 applies a positive product-growth economy weather at new game start")
	_expect(_product_market_float(product_market, "环晶电池", "route_flow_multiplier") >= 1.35, "流星哨兵 applies a positive route-flow economy weather at new game start")
	var basic_card_price := int(main.call("_card_price", "移动1"))
	var premium_card_price := int(main.call("_card_price", "垄断协议1"))
	var first_monster_card := String(main.call("_monster_card_name", 0, 1))
	_expect(String(main.call("_card_display_name", "怪兽·孢雾海皇4")).contains("IV级") and not String(main.call("_card_display_name", "怪兽·孢雾海皇4")).contains("Lv"), "visible card names use Roman-numeral rank text without legacy Lv labels")
	_expect(premium_card_price > basic_card_price, "card prices rise with the card's economic power cost")
	_expect(int(main.call("_card_price", "价格套利2")) == int(main.call("_card_price", "价格套利1")), "higher-rank economy cards keep the same rank-I base price")
	_expect(int(main.call("_card_price", "短期订单2")) == int(main.call("_card_price", "短期订单1")), "temporary contract upgrades keep the same rank-I base price")
	_expect(int(main.call("_card_price", "远期采购2")) == int(main.call("_card_price", "远期采购1")), "product contract upgrades keep the same rank-I base price")
	var growth_strategy_text := _card_presentation_text(main, main.call("_make_skill", "城市融资1") as Dictionary, "strategy_route_label")
	var speculation_strategy_text := _card_presentation_text(main, main.call("_make_skill", "城市做空1") as Dictionary, "strategy_route_label")
	var intel_strategy_text := _card_presentation_text(main, main.call("_make_skill", "业主透镜1") as Dictionary, "strategy_route_label")
	var monster_strategy_text := _card_presentation_text(main, main.call("_make_skill", first_monster_card) as Dictionary, "strategy_route_label")
	var growth_budget_text := _diagnostics(main).card_budget_text("城市融资1", main.call("_make_skill", "城市融资1"))
	var monster_budget_text := _diagnostics(main).card_budget_text(first_monster_card, main.call("_make_skill", first_monster_card))
	_expect(growth_strategy_text.contains("城市成长") and speculation_strategy_text.contains("金融投机") and intel_strategy_text.contains("情报推理") and monster_strategy_text.contains("怪兽路线"), "card strategy summaries are derived for economy, speculation, intel, and monster routes")
	_expect(growth_budget_text.contains("强度预算") and growth_budget_text.contains("主强度") and growth_budget_text.contains("制衡") and monster_budget_text.contains("怪兽"), "card strength budgets explain power drivers and counterplay from data fields")
	_expect(_verify_development_route_balance_baseline(main), "card pool exposes AI-readable development routes with card coverage, rank ladders, and profile preferences")
	_expect(_verify_development_route_pressure_audit(main), "development route pressure audit proves core strategies have money pressure, gates, clues, and AI coverage")
	_expect(_verify_direct_player_interaction_cards(main), "direct player-interaction cards cover 拆牌、牵牌、产权冻结、全场齐射 with target-player UI, balance gates, and anonymous clue rules")
	_expect(_verify_direct_interaction_balance_audit(main), "direct-interaction balance audit gates strong pressure with regional GDP share, public clues, and counter windows")
	_expect(_verify_temporary_decision_blueprints(main), "temporary decision UI has reusable blueprints for discard, contract, monster target, player target, and monster wager modules")
	_expect(_verify_ai_monster_wager_policy(main), "AI monster-wager bets use strength, ownership, city-risk, public stake, and hidden scoring metadata")
	_expect(_verify_ten_hour_route_pack(main), "ten-hour route pack adds complete repair, lockdown, intel-bounty, and route-weather ladders with AI-readable fields")
	_expect(_card_presentation_text(main, main.call("_make_skill", "城市融资1") as Dictionary, "art_stats").contains("城市成长"), "card face stats show the strategy route for non-monster cards")
	_expect(int(main.call("_card_price", first_monster_card)) > basic_card_price, "monster cards have priced card faces in the shared card economy")
	_expect(_verify_card_codex_uses_unified_categories(main), "card codex treats monster cards as cards and browses them through subcategories")
	var runtime_balance_model: RefCounted = RUNTIME_BALANCE_MODEL_SCRIPT.new()
	_expect(["高阶档", "旗舰档"].has(String(runtime_balance_model.call("card_price_tier_text", premium_card_price))), "high-leverage economy cards map into an explicit non-basic price tier")
	_expect(_verify_v06_market_rule_contract(), "v0.6 market contract keeps sunlight eligibility, additive monster pressure, upward rounding, and five-second quote locks")
	_expect(_verify_reacquired_card_upgrade_rules(main), "reacquiring an owned card upgrades its family and stops at rank IV")
	_expect(_verify_card_rank_ladders_are_complete(main), "all base card families expose non-regressing I-IV rank ladders at the rank-I price")
	_expect(_verify_playable_card_resolution_coverage(main), "all codex cards and generated monster fixed-skill cards have concrete resolution handlers")
	_expect(_verify_agent_policy_audit_report(main), "test-only Agent audit reports AI candidate metadata, monster target weights, hidden-info leaks, and missing handlers without player UI exposure")
	_expect(_verify_hidden_info_leak_audit(main), "player-facing UI does not leak AI reason, exact scores, pressure buckets, decision samples, or private rival state")
	_mark_smoke_progress("card supply and product ecosystem")
	_expect(_all_card_supply_entries_are_base_rank(main, districts), "card supplies and codex indexes offer base copies while upgrades happen through hand merging")
	_expect(_all_districts_have_four_to_five_cards(districts), "each district receives four to five available cards")
	_expect(_all_district_cards_have_sources(districts), "district card choices track their source")
	_expect(_has_monster_card_source(districts), "monster cards are explicitly mixed into district card supplies")
	var card_supply_layers := _diagnostics(main).card_supply_layer_report()
	_expect(
		int(card_supply_layers.get("codex_count", 0)) >= int(card_supply_layers.get("run_pool_count", 0))
		and int(card_supply_layers.get("run_pool_count", 0)) > 0
		and int(card_supply_layers.get("district_supply_count", 0)) > 0
		and int(card_supply_layers.get("district_unique_count", 0)) > 0
		and int(card_supply_layers.get("filter_violation_count", 0)) == 0,
		"card supply layer report separates full codex, current-planet pool, and district supply without filter violations"
	)
	var product_ecosystem := _diagnostics(main).product_ecosystem_report()
	var product_strategy_counts := product_ecosystem.get("strategy_counts", {}) as Dictionary
	_expect(
		int(product_ecosystem.get("catalog_count", 0)) >= 40
		and int(product_ecosystem.get("ocean_catalog_count", 0)) >= 12
		and int(product_ecosystem.get("profile_complete_count", 0)) == int(product_ecosystem.get("catalog_count", -1)),
		"product catalog has broad goods coverage and complete temporary art/profile fields"
	)
	_expect(
		int(product_ecosystem.get("run_product_count", 0)) > 0
		and int(product_ecosystem.get("run_ocean_count", 0)) > 0
		and int(product_ecosystem.get("run_land_count", 0)) > 0
		and int(product_ecosystem.get("district_product_slots", 0)) > 0
		and int(product_ecosystem.get("district_demand_slots", 0)) > 0
		and not product_strategy_counts.is_empty(),
		"product ecosystem report exposes current-run goods, land/ocean split, supply/demand slots, and strategy opportunities"
	)
	_expect(_visual_cue_array(main, "movement_trails").size() > 0, "summoning starting monsters creates visible summon trails")
	_expect(_log_contains(main, "区域补给网完成"), "new game announces card pool generation")

	var terrain_counts := _count_terrain(districts)
	_expect(int(terrain_counts.get("land", 0)) > 0, "generated planet includes land regions")
	_expect(int(terrain_counts.get("ocean", 0)) > 0, "generated planet includes ocean regions")

	var selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	_expect(selected_district >= 0 and selected_district < districts.size(), "selected district is inside the generated map")
	_expect(main.get("map_view") is Control, "main map view is built")
	var main_map_view := main.get("map_view") as Control
	_mark_smoke_progress("map and city gameplay")
	runtime_screen = main.get("runtime_game_screen") as Control
	var runtime_planet_board: Control = null
	var runtime_map_host: Control = null
	var runtime_hand_rack: Control = null
	var runtime_player_board: Control = null
	if runtime_screen != null:
		runtime_planet_board = runtime_screen.find_child("PlanetBoard", true, false) as Control
		runtime_map_host = runtime_screen.find_child("MapHost", true, false) as Control
		runtime_hand_rack = runtime_screen.find_child("HandRack", true, false) as Control
		runtime_player_board = runtime_screen.find_child("PlayerBoard", true, false) as Control
	var runtime_map_rect := Rect2()
	var runtime_planet_rect := Rect2()
	var runtime_hand_rect := Rect2()
	var runtime_player_rect := Rect2()
	if runtime_map_host != null:
		runtime_map_rect = runtime_map_host.get_global_rect()
	if runtime_planet_board != null:
		runtime_planet_rect = runtime_planet_board.get_global_rect()
	if runtime_hand_rack != null:
		runtime_hand_rect = runtime_hand_rack.get_global_rect()
	if runtime_player_board != null:
		runtime_player_rect = runtime_player_board.get_global_rect()
	_expect(
		(main_map_view != null and main_map_view.custom_minimum_size.y >= 420.0 and _container_label_text_contains(main, "星球赌桌") and _container_label_text_contains(main, "赌桌中央"))
		or (main_map_view != null and runtime_planet_board != null and runtime_map_host != null and runtime_player_board != null and main_map_view.get_parent() == runtime_map_host and runtime_map_rect.size.y >= 220.0 and absf(runtime_map_rect.size.x - runtime_map_rect.size.y) <= 4.0 and runtime_planet_rect.size.y > runtime_player_rect.size.y),
		"main play table keeps the planet as a large centered gambling-table focus"
	)
	_expect(_map_view_has_betting_table_theme(), "map view draws a felt-table rim with small chips around the centered planet")
	_expect(_container_has_named_node(main, "MapLayerFocusRail") and _container_has_named_node(main, "MapLayerFocusChip") and _container_has_named_node(main, "MapLayerFocusStatus") and _container_label_text_contains(main, "图层:全图"), "main map exposes a compact board-game layer focus rail")
	var trade_product_before_route_view := String(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product)
	var map_toolbar := main.find_child("PlanetMapControlToolbar", true, false) as Control
	var route_layer_button := map_toolbar.find_child("MapLayerRouteButton", true, false) as Button if map_toolbar != null else null
	if route_layer_button != null:
		route_layer_button.emit_signal("pressed")
	_expect(String(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product) == trade_product_before_route_view and main_map_view != null and String(main_map_view.get("trade_product")).is_empty(), "route-layer UI opens only the local opt-in selector and does not auto-select a gameplay product or visible route")
	_expect(
		_container_label_text_contains(main, "桌边牌架")
		or (runtime_hand_rack != null and runtime_player_board != null and runtime_planet_board != null and runtime_hand_rect.size.y >= 78.0 and runtime_hand_rect.size.y < runtime_planet_rect.size.y * 0.55 and runtime_hand_rect.size.x > 300.0 and runtime_player_rect.position.y > runtime_planet_rect.position.y),
		"main play table treats hand cards as a smaller table-edge rack"
	)
	_expect(main.get("full_map_view") is Control, "fullscreen map view is built")
	main.call("_open_fullscreen_map")
	_expect(bool((main.get("full_map_overlay") as Control).visible) and _container_has_named_node(main, "FullscreenMapReadingHud") and _container_has_named_node(main, "FullscreenMapLayerHud") and _container_label_text_contains(main, "图层:全图") and _container_label_text_contains(main, "商品:") and _container_label_text_contains(main, "选区:"), "fullscreen map opens with a compact layer/product/district reading HUD")
	main.call("_close_fullscreen_map")
	_expect(_map_view_uses_unified_monster_markers(), "map view no longer exposes legacy A/B monster position state")
	_verify_globe_projection_interaction(main, selected_district)
	_verify_selected_district_card_interaction(main, selected_district)

	var buildable_district := _first_buildable_land_district(districts)
	_expect(buildable_district >= 0, "generated planet includes a buildable land district")
	if buildable_district >= 0:
		_verify_monster_resource_and_collision_system(main, buildable_district)
		_settle_all_active_monster_wagers(main, "烟测建城前清场")
		await process_frame
		_settle_all_active_monster_wagers(main, "烟测建城前二次清场")
		districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		buildable_district = _first_buildable_land_district(districts)
		_expect(buildable_district >= 0, "city build smoke has an undestroyed land district after monster collision checks")
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = buildable_district
		var facility_gate := await _v06_facility_owner_chain_snapshot()
		_expect(bool(facility_gate.get("market_ready", false)), "first-table city economy exposes one canonical public facility listing")
		_expect(bool(facility_gate.get("purchase_committed", false)) and int(facility_gate.get("slot_index", -1)) >= 0, "facility purchase commits once and places the canonical card in the player's authoritative hand")
		_expect(bool(facility_gate.get("cash_spent", false)), "facility purchase spends authoritative player cash")
		_expect(bool(facility_gate.get("play_finalized", false)), "facility play creates and finalizes the authoritative city-economy source")
		_expect(bool(facility_gate.get("source_finalized", false)), "facility owner and CommodityFlow expose the finalized production source")
		_expect(_verify_card_play_flow_gate_and_one_shot(main, buildable_district), "rank-I cards can be condition-free, regional GDP gates block ineligible plays, and one-shot cards leave the hand")
		var ai_facility_bootstrap := _execute_ai_v06_facility_bootstrap_smoke(main)
		var auto_expansions := int(ai_facility_bootstrap.get("acted", 0))
		await process_frame
		var players_after_auto_expand := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		_expect(auto_expansions > 0, "AI facility bootstrap finalizes at least one authoritative rival economic source")
		_expect(int(ai_facility_bootstrap.get("sources_after", 0)) > int(ai_facility_bootstrap.get("sources_before", 0)), "AI facility bootstrap increases finalized rival economic sources")
		_expect(int(ai_facility_bootstrap.get("cash_after", -1)) < int(ai_facility_bootstrap.get("cash_before", -1)), "AI facility bootstrap spends authoritative rival cash")
		_expect(bool(ai_facility_bootstrap.get("public_available", false)), "AI facility bootstrap exposes a public capability result without private scoring weights")
		_expect(_verify_area_trade_contract_accept_and_decline(main), "area trade contracts open a separate non-blocking five-second decision window after reveal and resolve accept, reject, and timeout effects")
		_expect(not bool(ai_facility_bootstrap.get("human_source_after", true)), "AI facility bootstrap does not create an economic source for the human seat")
		_expect(_city_markers_include_unknown_rival(main), "active player's map marks rival auto-expanded cities as unknown owners")
		var rival_city_index := _first_rival_city_index(main, 0)
		_expect(rival_city_index >= 0, "rival auto expansion leaves an identifiable rival city for inference testing")
		if rival_city_index >= 0:
			var districts_for_guess := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
			var rival_city := (districts_for_guess[rival_city_index] as Dictionary).get("city", {}) as Dictionary
			var real_owner := int(rival_city.get("owner", -1))
			var cash_before_guess := _player_cash(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0)
			var intel_cash_before_guess := _intel_cash_from_stats(main, 0)
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = rival_city_index
			main.set("selected_guess_player", real_owner)
			main.call("_mark_selected_city_guess")
			await process_frame
			_expect(_intel_cash_from_stats(main, 0) == intel_cash_before_guess + 120, "correct private city-owner guess creates intelligence cash reward")
			_expect(_player_cash(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0) == cash_before_guess, "intelligence rewards remain separate from available cash and v0.5 qualification")
		var rival_cash_before_business := _rival_cash_total(players_after_auto_expand, 0)
		var business_actions := int(_ai_controller(main).call("_auto_rival_business_actions", true))
		await process_frame
		var players_after_business := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		_expect(business_actions > 0, "forced rival business actions create public inference clues")
		_expect(_rival_cash_total(players_after_business, 0) < rival_cash_before_business, "rival business actions spend hidden rival operating funds")
		_expect(_ai_decision_sample_count(players_after_business) > _ai_decision_sample_count(players_after_auto_expand), "AI business actions add more decision samples")
		_expect(_city_public_clue_exists(main), "rival business actions leave public clues on city records")
		_expect(_city_public_clue_history_exists(main), "city public clue history keeps recent anonymous business and contract evidence")
		var economy_coordinator := _runtime_card_coordinator(main)
		var receipts_before: Array = economy_coordinator.commodity_flow_recent_receipts(-1) if economy_coordinator != null and economy_coordinator.has_method("commodity_flow_recent_receipts") else []
		var economy_advance: Dictionary = economy_coordinator.advance_commodity_flow(60.0, {
			"game_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
			"player_count": _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size(),
		}) if economy_coordinator != null and economy_coordinator.has_method("advance_commodity_flow") else {}
		var market_cycle: Dictionary = economy_coordinator.tick_product_market_cycle(60.0) if economy_coordinator != null and economy_coordinator.has_method("tick_product_market_cycle") else {}
		await process_frame
		var receipts_after: Array = economy_coordinator.commodity_flow_recent_receipts(-1) if economy_coordinator != null and economy_coordinator.has_method("commodity_flow_recent_receipts") else []
		_expect(bool(economy_advance.get("advanced", false)), "CommodityFlow advances one authoritative economic interval through the Coordinator")
		_expect(receipts_after.size() >= receipts_before.size(), "CommodityFlow keeps sale receipts after the economic interval")
		_expect(bool(market_cycle.get("ticked", false)) or int(market_cycle.get("business_cycle_count", 0)) > 0, "ProductMarket advances its own business cycle through the Coordinator")
		_verify_economy_card_effects(main, buildable_district)
		var session_snapshot: Dictionary = economy_coordinator.session_to_save_data() if economy_coordinator != null and economy_coordinator.has_method("session_to_save_data") else {}
		_expect(not session_snapshot.is_empty(), "current session exposes the authoritative save owner snapshot")
		main.call("_open_main_menu")
		await process_frame
		_expect(not main.has_method("_save_run") and not main.has_method("_load_run"), "Main does not restore retired save wrappers")

	var menu_overlay := main.get("menu_overlay") as Control
	_expect(menu_overlay != null and menu_overlay.visible, "main menu overlay opens after setup")
	_mark_smoke_progress("menu and codex navigation")
	var menu_title_label := _menu_overlay_node(main, "MenuTitleLabel") as Label
	var menu_context_label := _menu_overlay_node(main, "MenuContextLabel") as Label
	var menu_body_label := _menu_overlay_node(main, "MenuBodyLabel") as Label
	var menu_back_button := _menu_overlay_node(main, "MenuBackButton") as Button
	var menu_continue_button := _menu_overlay_node(main, "MenuContinueButton") as Button
	var menu_quick_nav_row := _menu_overlay_node(main, "MenuQuickNavRow") as HBoxContainer
	var menu_interaction_hint_panel := _menu_overlay_node(main, "MenuInteractionHintPanel") as PanelContainer
	var menu_interaction_hint_label := _menu_overlay_node(main, "MenuInteractionHintLabel") as Label
	var menu_bestiary_prev_button := _menu_overlay_node(main, "MenuBestiaryPrevButton") as Button
	var menu_bestiary_next_button := _menu_overlay_node(main, "MenuBestiaryNextButton") as Button
	var menu_preview_box := _menu_overlay_node(main, "MenuPreviewBox") as VBoxContainer
	var menu_surface_panel := _menu_overlay_node(main, "MenuSurfacePanel") as PanelContainer
	var menu_content_scroll := _menu_overlay_node(main, "MenuContentScroll") as ScrollContainer
	var menu_content_box := _menu_overlay_node(main, "MenuContentBox") as VBoxContainer
	main.call("_open_main_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "太空辛迪加｜星球赌桌", "main menu opens with the table-lobby title")
	_expect(menu_context_label != null and not menu_context_label.visible, "root main menu hides breadcrumb text")
	_expect(menu_interaction_hint_panel != null and not menu_interaction_hint_panel.visible, "root main menu hides generic help strip")
	_expect(menu_quick_nav_row != null and not menu_quick_nav_row.visible, "root main menu no longer shows a top branch-button row")
	_expect(menu_surface_panel != null and menu_surface_panel.has_theme_stylebox_override("panel") and menu_surface_panel.custom_minimum_size.x >= 760.0, "main menu uses a reusable responsive surface panel")
	_expect(menu_content_scroll != null and not menu_content_scroll.follow_focus and menu_content_box != null and menu_preview_box != null and menu_preview_box.get_parent() == menu_content_box, "main menu keeps body and previews inside a scrollable content column without focus-jumping on hover")
	_expect(menu_overlay != null and _container_has_named_node(menu_overlay, "MainMenuPlanetLobbyPanel") and _container_has_named_node(menu_overlay, "MainMenuCommandCard") and _container_has_named_node(menu_overlay, "MainMenuUtilityRail"), "main menu arranges only the planet lobby and compact command buttons")
	_expect(menu_body_label != null and menu_body_label.text.contains("最后钱最多") and not menu_body_label.text.contains("游戏规则"), "main menu keeps only a short objective line")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "星球赌桌大厅") and _container_button_text_contains(menu_preview_box, "开始新局") and _container_button_text_contains(menu_preview_box, "资料库"), "main menu exposes current normal-game primary actions")
	_expect(menu_overlay != null and not _container_button_text_contains(menu_overlay, "新手战役") and not _container_button_text_contains(menu_overlay, "快速开局") and not _container_button_text_contains(menu_overlay, "首局任务"), "main menu has no legacy onboarding entry")
	_expect(menu_overlay != null and _container_label_text_contains(menu_overlay, "建城｜怪兽｜下注｜推理"), "main menu uses short player-facing command labels")
	_expect(menu_overlay != null and _container_button_has_stylebox(menu_overlay, "hover") and _container_button_has_stylebox(menu_overlay, "pressed"), "menu buttons expose reusable hover and pressed visual states")
	_expect(menu_overlay != null and not _container_button_text_contains(menu_overlay, "情报档案") and not _container_button_text_contains(menu_overlay, "经济总览") and not _container_button_text_contains(menu_overlay, "局势排名"), "main menu keeps in-game analysis pages out of the root lobby")
	_expect(menu_overlay != null and not _container_button_text_contains(menu_overlay, "选择四怪兽"), "main menu no longer exposes a separate monster-selection branch")
	_expect(menu_back_button != null and not menu_back_button.visible and menu_continue_button != null and not menu_continue_button.visible, "root menu does not show redundant global back/continue buttons")
	var player_count_before_setup := int(main.get("configured_player_count"))
	var role_indices_before_setup := _as_array(main.get("configured_role_indices")).duplicate(true)
	if role_indices_before_setup.is_empty():
		main.call("_ensure_configured_role_indices")
		role_indices_before_setup = _as_array(main.get("configured_role_indices")).duplicate(true)
	var current_players_before_setup := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size()
	main.call("_start_new_run_from_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "开局准备", "new-run entry opens the setup preview instead of immediately starting")
	_expect(menu_context_label != null and menu_context_label.text.contains("开局｜"), "setup branch updates the compact breadcrumb/help strip")
	_expect(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size() == current_players_before_setup, "opening setup preview does not wipe the current run")
	_expect(menu_body_label != null and menu_body_label.text.contains("公开角色") and menu_body_label.text.contains("起始怪兽"), "new-run setup explains role cards and the held starter monster")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "开始本局"), "new-run setup requires an explicit start confirmation")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "角色被动"), "new-run setup previews role passive rules")
	_expect(menu_preview_box != null and _container_card_art_kind_contains(menu_preview_box, "player_role"), "new-run setup previews player role-card art")
	_expect(menu_preview_box != null and _container_card_art_kind_contains(menu_preview_box, "monster_card"), "new-run setup previews starter monster-card art")
	_expect(menu_preview_box != null and _container_card_art_stats_contains(menu_preview_box, "不限区"), "new-run setup starter card art shows its unrestricted summon access")
	_expect(menu_preview_box != null and _container_has_meta(menu_preview_box, "setup_summary_chips") and _container_has_meta(menu_preview_box, "setup_seat_card") and _container_has_meta(menu_preview_box, "setup_seat_chips"), "new-run setup uses compact board-game setup chips and seat cards")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "目标¥") and _container_label_text_contains(menu_preview_box, "角色不重复") and _container_label_text_contains(menu_preview_box, "召唤自愿"), "new-run setup summary chips expose the key setup facts")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "固定技") and _container_label_text_contains(menu_preview_box, "日照牌架"), "new-run setup separates optional starter summoning from sunlit market access")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "随机角色") and not _container_label_text_contains(menu_preview_box, "主路线"), "new-run setup supports random AI roles while hiding AI internal development routes")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "上一个角色") and _container_button_text_contains(menu_preview_box, "下一个角色"), "new-run setup exposes per-player alien role switching")
	var first_role_before_setup := int(role_indices_before_setup[0]) if not role_indices_before_setup.is_empty() else 0
	main.call("_cycle_configured_role_for_player_from_new_game_menu", 0, 1)
	await process_frame
	var role_indices_after_cycle := _as_array(main.get("configured_role_indices"))
	var configured_preview_role := main.call("_make_configured_player_role_card", 0) as Dictionary
	_expect(role_indices_after_cycle.size() > 0 and int(role_indices_after_cycle[0]) != first_role_before_setup, "new-run setup can change an individual player's role card")
	_expect(int(configured_preview_role.get("role_index", -1)) == int(role_indices_after_cycle[0]), "configured role selection controls the role card used for new runs")
	main.call("_set_configured_role_for_player", 0, first_role_before_setup)
	await process_frame
	main.call("_open_new_game_setup_menu")
	await process_frame
	var preview_player_count := 8
	main.call("_set_configured_player_count_from_new_game_menu", preview_player_count)
	await process_frame
	_expect(int(main.get("configured_player_count")) == preview_player_count, "new-run setup can change the configured player count")
	main.call("_set_configured_ai_player_count_from_new_game_menu", 7)
	await process_frame
	_expect(int(main.get("configured_ai_player_count")) == 7 and menu_preview_box != null and _container_label_text_contains(menu_preview_box, "电脑对手7"), "new-run setup can configure a 3-8 seat PVE run with 2-7 AI opponents")
	main.call("_set_configured_player_count_from_new_game_menu", player_count_before_setup)
	await process_frame
	main.call("_set_configured_ai_player_count_from_new_game_menu", EXPECTED_AI_PLAYER_COUNT)
	await process_frame
	main.set("configured_role_indices", role_indices_before_setup)
	main.call("_ensure_configured_role_indices")
	main.call("_open_main_menu")
	await process_frame
	main.call("_open_rules_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "游戏规则", "rules menu opens from the main scene")
	_expect(menu_continue_button != null and not menu_continue_button.visible and menu_back_button != null and menu_back_button.visible, "rules subpage shows return navigation without a global continue button")
	_expect(menu_body_label != null and menu_body_label.text.contains("读桌顺序") and menu_body_label.text.contains("公开角色") and menu_body_label.text.contains("高阶牌检查地区GDP份额") and not menu_body_label.text.contains("Lv"), "rules menu opens with the current core loop in compact player language")
	_expect(menu_body_label != null and not menu_body_label.text.contains("所有牌都会公开展示") and not menu_body_label.text.contains("怪兽受伤会让归属玩家掉钱"), "rules top body no longer repeats dense detail prose")
	_expect(menu_body_label != null and menu_body_label.text.contains("开局：") and not menu_body_label.text.contains("Y切预设") and not menu_body_label.text.contains("AI训练") and not menu_body_label.text.contains("当前原型规则"), "rules menu removes development history, AI training, and obsolete debug controls")
	_expect(menu_body_label != null and not menu_body_label.text.contains("经营周期") and not menu_body_label.text.contains("经济周期"), "rules menu avoids cycle wording")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "牌桌规则速览") and _container_label_text_contains(menu_preview_box, "怪兽") and _container_label_text_contains(menu_preview_box, "公开牌轨"), "rules menu exposes a compact card-summary layer above the short rule text")
	var quick_nav_ids: Array[String] = []
	for entry_variant in _as_array(main.call("_menu_quick_nav_entries")):
		if entry_variant is Dictionary:
			quick_nav_ids.append(String((entry_variant as Dictionary).get("id", "")))
	_expect(menu_quick_nav_row != null and menu_quick_nav_row.visible and quick_nav_ids.has("rules") and quick_nav_ids.has("economy"), "rules subpage uses the scene-owned quick navigation with rules and economy routes")
	main.call("_open_economy_overview_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "经济总览", "economy overview remains reachable from menu actions")
	main.call("_open_standings_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "局势排名", "standings menu opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("预估结算资金"), "standings menu explains estimated settlement money")
	_expect(menu_body_label != null and menu_body_label.text.contains("公开异动") and menu_body_label.text.contains("对手现金、手牌和私密推理保持隐藏") and not menu_body_label.text.contains("对手计划") and not menu_body_label.text.contains("AI对局压力") and not menu_body_label.text.contains("反制建议") and not menu_body_label.text.contains("推荐卡牌路线"), "standings menu shows only public situation clues and hides AI route/bucket data")
	_expect(menu_body_label != null and menu_body_label.text.contains("情报待结算"), "standings keeps intelligence cash pending until final settlement")
	_expect(menu_body_label != null and menu_body_label.text.contains("存活城市1×"), "standings menu reflects built city assets")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "局势速览") and _container_label_text_contains(menu_preview_box, "终局条件") and _container_label_text_contains(menu_preview_box, "我的可见资金"), "standings menu exposes compact victory and cash summary cards")
	main.call("_open_economy_overview_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "经济总览", "economy overview opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("情报现金只在终局兑现"), "economy overview avoids revealing intelligence correctness early")
	_expect(menu_body_label != null and menu_body_label.text.contains("商品热榜") and menu_body_label.text.contains("低价/供给压制"), "economy overview shows product price gradients")
	_expect(menu_body_label != null and menu_body_label.text.contains("商路收入前景") and menu_body_label.text.contains("玩家经济隐私"), "economy overview shows route prospects while keeping rival economics private")
	_expect(menu_body_label != null and menu_body_label.text.contains("公开异动") and menu_body_label.text.contains("对手现金、手牌和私密推理保持隐藏") and not menu_body_label.text.contains("对手计划") and not menu_body_label.text.contains("AI对局压力") and not menu_body_label.text.contains("公开路线观察") and not menu_body_label.text.contains("推荐卡牌路线"), "economy overview shows public results while hiding AI route/bucket data")
	_expect(menu_body_label != null and menu_body_label.text.contains("经济天气") and menu_body_label.text.contains("最近卡牌余波"), "economy overview explains active product weather and recent card aftermath")
	_expect(menu_body_label != null and menu_body_label.text.contains("最近城市公开线索") and menu_body_label.text.contains("类型:") and menu_body_label.text.contains("线索商品:"), "economy overview aggregates structured anonymous city clues")
	_expect(menu_body_label != null and menu_body_label.text.contains("最近怪兽资金线索") and menu_body_label.text.contains("最大生命比例"), "economy overview explains monster damage cash clues")
	_expect(menu_body_label != null and menu_body_label.text.contains("当前玩家推理板") and menu_body_label.text.contains("城市私标") and menu_body_label.text.contains("公开卡牌归属") and menu_body_label.text.contains("卡牌条件反推") and menu_body_label.text.contains("公开怪兽归属"), "economy overview groups public and private inference clues without resolving hidden truth")
	_expect(menu_body_label != null and menu_body_label.text.contains("公开状态["), "economy overview shows unified public status tags")
	_expect(menu_body_label != null and menu_body_label.text.contains("流水"), "economy overview shows player economy ledger entries")
	_expect(menu_body_label != null and menu_body_label.text.contains("收入拆解") and menu_body_label.text.contains("合约"), "economy overview shows city income breakdowns and temporary contract status")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "经济速览") and _container_label_text_contains(menu_preview_box, "商品热榜") and _container_label_text_contains(menu_preview_box, "公开异动") and _container_label_text_contains(menu_preview_box, "匿名线索"), "economy overview exposes compact GDP, product, route, public-situation, and clue summary cards")
	main.call("_open_intel_dossier_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "intel dossier opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("情报换钱") and menu_body_label.text.contains("当前不揭示正误"), "intel dossier explains money settlement without revealing truth early")
	_expect(menu_body_label != null and menu_body_label.text.contains("城市业主情报") and menu_body_label.text.contains("终局范围"), "intel dossier summarizes private city-owner guesses")
	_expect(menu_body_label != null and menu_body_label.text.contains("卡牌归属档案") and menu_body_label.text.contains("押注"), "intel dossier summarizes anonymous card-owner betting status")
	_expect(menu_body_label != null and menu_body_label.text.contains("怪兽资金档案") and menu_body_label.text.contains("城市公开线索档案"), "intel dossier groups monster cash and city clue evidence")
	_expect(menu_body_label != null and menu_body_label.text.contains("调查优先级") and menu_body_label.text.contains("优先级"), "intel dossier ranks city-owner leads by investigation priority")
	menu_preview_box = _menu_overlay_node(main, "MenuPreviewBox") as VBoxContainer
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "查看区域线索"), "intel dossier exposes region clue jump buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "查看卡牌线索"), "intel dossier exposes card clue jump buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "标玩家") and _container_button_text_contains(menu_preview_box, "清除"), "intel dossier exposes city-owner mark buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "卡牌条件") and _container_button_text_contains(menu_preview_box, "怪兽资金"), "intel dossier exposes city-owner mark reason buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "打开经济总览"), "intel dossier keeps an economy overview jump")
	var dossier_rival_city_index := _first_rival_city_index(main, 0)
	if dossier_rival_city_index >= 0:
		main.call("_mark_city_guess_from_intel", dossier_rival_city_index, -1)
		await process_frame
		var players_after_intel_clear := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var guesses_after_intel_clear := (players_after_intel_clear[0] as Dictionary).get("city_guesses", {}) as Dictionary
		_expect(not guesses_after_intel_clear.has(dossier_rival_city_index), "intel dossier can clear a private city-owner mark")
		main.call("_mark_city_guess_from_intel", dossier_rival_city_index, 1)
		await process_frame
		var players_after_intel_mark := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var guesses_after_intel_mark := (players_after_intel_mark[0] as Dictionary).get("city_guesses", {}) as Dictionary
		_expect(int(guesses_after_intel_mark.get(dossier_rival_city_index, -1)) == 1, "intel dossier can update a private city-owner mark")
		main.call("_set_city_guess_confidence_from_intel", dossier_rival_city_index, 3)
		await process_frame
		var players_after_confidence := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var confidence_after_intel := (players_after_confidence[0] as Dictionary).get("city_guess_confidence", {}) as Dictionary
		_expect(int(confidence_after_intel.get(dossier_rival_city_index, 0)) == 3, "intel dossier can update city-owner mark confidence")
		_expect(menu_body_label != null and menu_body_label.text.contains("置信:高") and menu_body_label.text.contains("置信分布"), "intel dossier displays city-owner mark confidence")
		main.call("_set_city_guess_reason_from_intel", dossier_rival_city_index, "card")
		await process_frame
		var players_after_reason := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var reasons_after_intel := (players_after_reason[0] as Dictionary).get("city_guess_reasons", {}) as Dictionary
		_expect(String(reasons_after_intel.get(dossier_rival_city_index, "")) == "card", "intel dossier can update city-owner mark reason")
		_expect(menu_body_label != null and menu_body_label.text.contains("理由:卡牌条件") and menu_body_label.text.contains("理由分布"), "intel dossier displays city-owner mark reason")
		var intel_city_entries := _as_array(main.call("_intel_city_guess_entries", 0, 6))
		_expect(not intel_city_entries.is_empty() and int((intel_city_entries[0] as Dictionary).get("priority", -1)) >= 0, "intel dossier computes non-negative city investigation priority")
		var intel_player_snapshot := (_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[0] as Dictionary)
		var saved_confidence := intel_player_snapshot.get("city_guess_confidence", {}) as Dictionary
		var saved_reasons := intel_player_snapshot.get("city_guess_reasons", {}) as Dictionary
		_expect(int(saved_confidence.get(dossier_rival_city_index, 0)) == 3, "private city-owner mark confidence remains on the active player state")
		_expect(String(saved_reasons.get(dossier_rival_city_index, "")) == "card", "private city-owner mark reason remains on the active player state")
	main.call("_open_intel_region_codex_link", buildable_district)
	await process_frame
	var intel_back_button := _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "区域图鉴" and intel_back_button != null and intel_back_button.text == "返回情报档案", "intel dossier region links return to the dossier")
	_expect_runtime_map_focus_target(main, buildable_district, "intel dossier region link rotates the central planet to the target region")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "region codex returns to the intel dossier")
	main.call("_open_intel_card_codex_link", "城市融资1")
	await process_frame
	intel_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴" and intel_back_button != null and intel_back_button.text == "返回缩略图", "intel dossier card links open card detail before returning to thumbnails")
	main.call("_back_from_catalog_menu")
	await process_frame
	intel_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴" and menu_body_label != null and menu_body_label.text.contains("卡牌图鉴") and intel_back_button != null and intel_back_button.text == "返回情报档案", "card detail returns to thumbnail page before the intel dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "card thumbnail page returns to the intel dossier")
	main.call("_open_intel_monster_codex_link", 0)
	await process_frame
	intel_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案" and intel_back_button != null and intel_back_button.text == "返回缩略图", "intel dossier monster links open monster detail before returning to thumbnails")
	main.call("_back_from_catalog_menu")
	await process_frame
	intel_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案" and menu_body_label != null and menu_body_label.text.contains("怪兽生态｜") and intel_back_button != null and intel_back_button.text == "返回情报档案", "monster detail returns to thumbnail page before the intel dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "monster thumbnail page returns to the intel dossier")
	main.call("_open_intel_product_codex_link", "活体芯片")
	await process_frame
	intel_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "商品图鉴" and intel_back_button != null and intel_back_button.text == "返回缩略图", "intel dossier product links open product detail before returning to thumbnails")
	main.call("_back_from_catalog_menu")
	await process_frame
	intel_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "商品图鉴" and menu_body_label != null and menu_body_label.text.contains("商品目录｜") and intel_back_button != null and intel_back_button.text == "返回情报档案", "product detail returns to thumbnail page before the intel dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "product thumbnail page returns to the intel dossier")
	main.call("_open_compendium_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "图鉴", "unified compendium opens from the main scene")
	var menu_catalog_nav_row := _menu_overlay_node(main, "MenuCatalogNavRow") as HBoxContainer
	var compendium_back_button := _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_catalog_nav_row != null and menu_catalog_nav_row.visible and compendium_back_button != null and compendium_back_button.visible and compendium_back_button.text == "返回主菜单", "compendium exposes a visible local exit button back to the main menu")
	_expect(menu_body_label != null and menu_body_label.text.contains("角色图鉴") and menu_body_label.text.contains("商品图鉴") and menu_body_label.text.contains("区域图鉴"), "compendium introduces all sub-codex sections")
	menu_preview_box = _menu_overlay_node(main, "MenuPreviewBox") as VBoxContainer
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "角色图鉴"), "compendium exposes role codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "怪兽生态档案"), "compendium exposes monster ecology dossier")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "卡牌图鉴"), "compendium exposes card codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "商品图鉴"), "compendium exposes product codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "区域图鉴"), "compendium exposes region codex")
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var first_role := (players[0] as Dictionary).get("role_card", {}) as Dictionary
	main.call("_open_role_codex_from_compendium")
	await process_frame
	var menu_bestiary_back_button := _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "角色图鉴", "role codex opens from the compendium")
	_expect(menu_catalog_nav_row != null and menu_catalog_nav_row.visible and menu_bestiary_back_button != null and menu_bestiary_back_button.visible and menu_bestiary_back_button.text == "返回图鉴", "role codex returns to the compendium with visible local navigation")
	_expect(menu_body_label != null and menu_body_label.text.contains("角色卡") and menu_body_label.text.contains("特征") and menu_body_label.text.contains("被动") and menu_body_label.text.contains("起始怪兽"), "role codex explains role traits, passives, and independent starter monster choice")
	_expect(menu_preview_box != null and _container_card_art_kind_contains(menu_preview_box, "player_role"), "role codex displays role cards with the shared card-art component")
	_expect(menu_preview_box != null and _container_card_art_stats_contains(menu_preview_box, "公开身份") and not _container_card_art_stats_contains(menu_preview_box, "起始:"), "role codex card art presents public identity without starter-monster fingerprints")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "独立选择") and not _container_button_text_contains(menu_preview_box, "点击查看卡牌图鉴") and not _container_button_text_contains(menu_preview_box, "查看怪兽生态档案"), "role codex does not link roles to starter monster cards")
	var old_role_text := menu_body_label.text
	main.call("_cycle_menu_catalog", 1)
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "角色图鉴" and menu_body_label.text != old_role_text, "role codex next button logic changes pages")
	main.call("_open_bestiary_from_compendium")
	await process_frame
	menu_bestiary_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案", "monster ecology dossier opens from the compendium")
	_expect(menu_overlay != null and not _container_button_text_contains(menu_overlay, "仅查看") and not _container_button_text_contains(menu_overlay, "开局不再预选怪兽"), "monster codex has no hidden legacy lineup controls")
	_expect(menu_bestiary_back_button != null and menu_bestiary_back_button.text == "返回图鉴", "monster thumbnail codex returns to the compendium")
	_expect(menu_body_label != null and menu_body_label.text.contains("怪兽生态｜") and menu_body_label.text.contains("行动概率") and menu_body_label.text.contains("怪兽牌在卡牌图鉴") and menu_body_label.text.contains("本页") and menu_body_label.text.contains("悬停预览") and menu_body_label.text.contains("双击详情"), "monster ecology dossier opens as a thumbnail atlas focused on ecology while monster cards stay in the card codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "缩略图下一页") and _container_label_text_contains(menu_preview_box, "生态速览") and _container_label_text_contains(menu_preview_box, "悬停预览"), "monster codex thumbnail page exposes paging and hover preview")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "飞行") and _container_label_text_contains(menu_preview_box, "水栖") and _container_label_text_contains(menu_preview_box, "陆行"), "monster codex thumbnail page summarizes movement ecology coverage")
	_expect(menu_bestiary_prev_button != null and not menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and not menu_bestiary_next_button.visible, "monster codex hides detail previous/next buttons on the thumbnail page")
	var bestiary_scroll_before := 48
	if menu_content_scroll != null:
		menu_content_scroll.scroll_vertical = bestiary_scroll_before
		bestiary_scroll_before = int(menu_content_scroll.scroll_vertical)
	main.call("_preview_bestiary_entry", 0, true)
	await process_frame
	await process_frame
	_expect(menu_content_scroll != null and (bestiary_scroll_before <= 0 or int(menu_content_scroll.scroll_vertical) == bestiary_scroll_before), "monster codex hover preview preserves scroll position when the page is scrollable")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "HP:") and _container_label_text_contains(menu_preview_box, "生态位:") and _container_label_text_contains(menu_preview_box, "行动定位:") and _container_label_text_contains(menu_preview_box, "行动:"), "monster codex hover preview shows the selected monster details")
	main.call("_open_bestiary_detail", 0)
	await process_frame
	menu_bestiary_back_button = _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_body_label != null and menu_body_label.text.contains("正面经济天气"), "monster codex shows positive economy abilities")
	_expect(menu_body_label != null and menu_body_label.text.contains("IV级") and menu_body_label.text.contains("权重修正"), "monster codex explains rank-based action probability shifts")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "生态位") and _container_label_text_contains(menu_preview_box, "资源与经济") and _container_label_text_contains(menu_preview_box, "行动定位") and _container_label_text_contains(menu_preview_box, "固定技能成长"), "monster detail uses readable ecology identity cards")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "¥"), "monster codex exposes linked monster-card buttons with prices")
	_expect(menu_preview_box != null and _container_button_tooltip_contains(menu_preview_box, "生命"), "monster codex card links expose card details on hover")
	_expect(menu_preview_box != null and _container_button_tooltip_contains(menu_preview_box, "在场"), "monster codex card links expose field duration on hover")
	_expect(menu_preview_box != null and _container_button_tooltip_contains(menu_preview_box, "召唤区域"), "monster codex card links expose summon-region restrictions on hover")
	_expect(menu_bestiary_back_button != null and menu_bestiary_back_button.text == "返回缩略图" and menu_bestiary_prev_button != null and menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and menu_bestiary_next_button.visible, "monster detail exposes previous/next and a return-to-thumbnails button")
	var old_bestiary_text := menu_body_label.text
	main.call("_cycle_menu_catalog", 1)
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案" and menu_body_label.text != old_bestiary_text, "monster detail next button logic changes pages")
	main.call("_open_card_codex_by_name", first_monster_card)
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴" and menu_body_label != null and menu_body_label.text.contains("怪兽牌") and menu_body_label.text.contains("生命"), "monster-card link can jump to the matching card codex entry")
	main.call("_open_bestiary_from_compendium")
	await process_frame
	main.call("_open_card_codex_from_compendium")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴", "card codex opens from the compendium")
	_expect(menu_continue_button != null and not menu_continue_button.visible and menu_back_button != null and not menu_back_button.visible, "card codex hides global continue/back buttons and keeps only codex-local navigation")
	menu_catalog_nav_row = _menu_overlay_node(main, "MenuCatalogNavRow") as HBoxContainer
	var card_thumbnail_back_button := _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_catalog_nav_row != null and menu_catalog_nav_row.visible and card_thumbnail_back_button != null and card_thumbnail_back_button.visible and card_thumbnail_back_button.text == "返回图鉴", "card codex thumbnail page exposes a visible local back button")
	_expect(menu_interaction_hint_label != null and menu_interaction_hint_label.text.contains("悬停") and menu_interaction_hint_label.text.contains("双击详情") and menu_interaction_hint_label.text.length() <= 12, "card codex thumbnail page exposes a compact shared hover/detail interaction hint")
	_expect(menu_body_label != null and menu_body_label.text.contains("卡牌图鉴") and menu_body_label.text.contains("本局牌池") and menu_body_label.text.contains("区域补给") and menu_body_label.text.contains("双击看详情"), "card codex opens as a concise responsive thumbnail grid")
	_expect(menu_preview_box != null and _container_has_named_node(menu_preview_box, "CardCodexCategoryRail") and _container_button_text_contains(menu_preview_box, "怪兽") and _container_button_text_contains(menu_preview_box, "期货") and _container_button_text_contains(menu_preview_box, "互动") and _container_button_text_contains(menu_preview_box, "军队"), "card codex thumbnail page keeps strict card categories in a visible top chip rail")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "缩略图下一页") and _container_label_text_contains(menu_preview_box, "悬停预览") and not _container_label_text_contains(menu_preview_box, "旧的普通牌池") and not _container_label_text_contains(menu_preview_box, "相位反制") and not _container_label_text_contains(menu_preview_box, "牌路总览") and not _container_label_text_contains(menu_preview_box, "AI发展路线") and not _container_label_text_contains(menu_preview_box, "AI偏好"), "card codex thumbnail page stays browse-first without legacy labels or development-route prose")
	_expect(menu_bestiary_prev_button != null and not menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and not menu_bestiary_next_button.visible, "card codex hides detail previous/next buttons on the thumbnail page")
	var card_codex_scroll_before := 64
	if menu_content_scroll != null:
		menu_content_scroll.scroll_vertical = card_codex_scroll_before
		card_codex_scroll_before = int(menu_content_scroll.scroll_vertical)
	main.call("_preview_card_codex_card", "城市融资1", true)
	await process_frame
	await process_frame
	_expect(menu_content_scroll != null and (card_codex_scroll_before <= 0 or int(menu_content_scroll.scroll_vertical) == card_codex_scroll_before), "card codex hover preview preserves scroll position when the page is scrollable")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "城市融资") and _container_label_text_contains(menu_preview_box, "I→IV"), "card codex hover preview shows the selected card details")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "路线：城市成长") and not _container_label_text_contains(menu_preview_box, "预算:"), "card codex hover preview explains the card's strategic route without internal budget text")
	main.call("_open_card_codex_detail", "城市融资1")
	await process_frame
	var card_codex_back_button := _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_interaction_hint_label != null and menu_interaction_hint_label.text.contains("卡面") and menu_interaction_hint_label.text.contains("梯度") and menu_interaction_hint_label.text.length() <= 18, "card detail page exposes a compact interaction hint")
	_expect(menu_continue_button != null and not menu_continue_button.visible and menu_back_button != null and not menu_back_button.visible, "card detail keeps global menu buttons hidden")
	_expect(menu_body_label != null and menu_body_label.text.contains("¥") and menu_body_label.text.contains("不需要指定怪兽") and not menu_body_label.text.contains("Lv"), "card detail shows concise price and target information with Roman-numeral ranks")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "牌面定位") and _container_label_text_contains(menu_preview_box, "费用与门槛") and _container_label_text_contains(menu_preview_box, "核心效果") and _container_label_text_contains(menu_preview_box, "关键数值") and not _container_label_text_contains(menu_preview_box, "关键字段"), "card detail uses TCG-style player-facing sections for purpose, cost, effect, and key numbers")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "I→IV 强化") and not _container_label_text_contains(menu_preview_box, "预算:"), "card detail shows a structured I-IV level-gradient grid without internal budget text")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "结算演出") and _container_label_text_contains(menu_preview_box, "匿名"), "card detail shows the public anonymous resolution presentation")
	_expect(card_codex_back_button != null and card_codex_back_button.text == "返回缩略图" and menu_bestiary_prev_button != null and menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and menu_bestiary_next_button.visible, "card detail exposes previous/next and a return-to-thumbnails button")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "匿名投资光幕"), "city economy cards use their own resolution animation script")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_body_label != null and menu_body_label.text.contains("卡牌图鉴"), "card detail can return to the thumbnail grid")
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = "活体芯片"
	main.call("_open_product_codex_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "商品图鉴", "product codex opens from the compendium")
	_expect(menu_body_label != null and menu_body_label.text.contains("商品目录｜") and menu_body_label.text.contains("本页") and menu_body_label.text.contains("本局出现") and menu_body_label.text.contains("主打法") and menu_body_label.text.contains("双击详情"), "product codex opens as a concise thumbnail grid")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "缩略图下一页") and _container_label_text_contains(menu_preview_box, "本局商品生态") and _container_label_text_contains(menu_preview_box, "策略入口") and _container_label_text_contains(menu_preview_box, "商品路线分布") and _container_label_text_contains(menu_preview_box, "牌路连接") and _container_label_text_contains(menu_preview_box, "悬停预览"), "product codex thumbnail page exposes paging, ecosystem overview, and hover preview")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "主策略:"), "product thumbnails expose a primary strategy tag before opening detail")
	_expect(menu_bestiary_prev_button != null and not menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and not menu_bestiary_next_button.visible, "product codex hides detail previous/next buttons on the thumbnail page")
	var codex_navigation: Dictionary = main.call("_codex_navigation_state_snapshot") if main.has_method("_codex_navigation_state_snapshot") else {}
	var product_navigation: Dictionary = codex_navigation.get("product", {}) if codex_navigation.get("product", {}) is Dictionary else {}
	var product_preview_index := int(product_navigation.get("selected_index", 0))
	var product_codex_scroll_before := 56
	if menu_content_scroll != null:
		menu_content_scroll.scroll_vertical = product_codex_scroll_before
		product_codex_scroll_before = int(menu_content_scroll.scroll_vertical)
	main.call("_preview_product_codex_entry", product_preview_index, true)
	await process_frame
	await process_frame
	var product_codex_scroll_after := int(menu_content_scroll.scroll_vertical) if menu_content_scroll != null else -1
	_expect(menu_content_scroll != null and (product_codex_scroll_before <= 0 or product_codex_scroll_after == product_codex_scroll_before), "product codex hover preview preserves scroll position when the page is scrollable")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "活体芯片") and _container_label_text_contains(menu_preview_box, "价格带") and _container_label_text_contains(menu_preview_box, "策略:"), "product codex hover preview shows the selected product strategy details")
	main.call("_open_product_codex_detail", product_preview_index)
	await process_frame
	var product_codex_back_button := _menu_overlay_node(main, "MenuBestiaryBackButton") as Button
	_expect(menu_body_label != null and menu_body_label.text.contains("活体芯片"), "product detail opens on the currently selected trade product")
	_expect(menu_body_label != null and menu_body_label.text.contains("价格带") and menu_body_label.text.contains("当前价"), "product codex shows product price and tier information")
	_expect(menu_body_label != null and menu_body_label.text.contains("经济天气"), "product codex shows product growth and flow weather")
	_expect(menu_body_label != null and menu_body_label.text.contains("策略摘要") and menu_body_label.text.contains("期货/仓储") and menu_body_label.text.contains("怪兽偏好") and menu_body_label.text.contains("相关卡牌"), "product codex shows strategy, futures, monster, and related-card panels")
	_expect(menu_body_label != null and menu_body_label.text.contains("【商品卡】") and menu_body_label.text.contains("【市场面板】") and menu_body_label.text.contains("【策略面板】") and menu_body_label.text.contains("【金融与天气】") and menu_body_label.text.contains("【生态与卡牌】"), "product detail uses TCG-style readable strategy sections")
	_expect(menu_body_label != null and menu_body_label.text.contains("商品相关城市线索"), "product codex can filter city clues by product")
	_expect(product_codex_back_button != null and product_codex_back_button.text == "返回缩略图" and menu_bestiary_prev_button != null and menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and menu_bestiary_next_button.visible, "product detail exposes previous/next and a return-to-thumbnails button")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_body_label != null and menu_body_label.text.contains("商品目录｜"), "product detail can return to the thumbnail grid")
	main.call("_open_region_codex_menu", buildable_district)
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "区域图鉴", "region codex opens from the compendium")
	_expect_runtime_map_focus_target(main, buildable_district, "region codex jump rotates the central planet to the opened region")
	_expect(menu_body_label != null and menu_body_label.text.contains("区域可提供卡牌"), "region codex lists the cards available from a region")
	_expect(menu_body_label != null and menu_body_label.text.contains("真实业主不公开"), "region codex preserves hidden city ownership")
	_expect(menu_body_label != null and menu_body_label.text.contains("流通加速"), "region codex shows city route-flow acceleration status")
	_expect(menu_body_label != null and menu_body_label.text.contains("收入拆解") and menu_body_label.text.contains("生产明细"), "region codex shows city income breakdown details")

	_verify_special_monster_passives(main)
	_verify_card_art_script()
	_verify_monster_art_script()
	if buildable_district >= 0:
		var districts_before_destroy := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		var built_district := districts_before_destroy[buildable_district] as Dictionary
		var built_city := built_district.get("city", {}) as Dictionary
		if bool(built_city.get("active", false)):
			main.call("_damage_district", buildable_district, int(built_district.get("hp", 10)) + 2, "烟测怪兽践踏")
			await process_frame
			_expect(_map_effects_contain(main, "city_destroyed"), "monster trampling a city emits a temporary city-collapse animation")

	main.queue_free()
	await process_frame
	_mark_smoke_progress("finish")
	_finish()


func _verify_selected_district_card_interaction(main: Node, district_index: int) -> void:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if district_index < 0 or district_index >= districts.size():
		_expect(false, "selected district card interaction has a valid district")
		return
	var district := districts[district_index] as Dictionary
	var choices := _as_array(district.get("card_choices", []))
	_expect(not choices.is_empty(), "selected district exposes available cards")
	if choices.is_empty():
		return
	var card_name := String(choices[0])
	main.call("_preview_district_card", card_name, false)
	_expect(String(main.get("previewed_district_card")) == card_name, "hover preview selects the district card")
	_expect(String(main.get("selected_market_skill")) == card_name, "hover preview makes the card the acquire target")
	main.call("_open_district_supply_from_map", district_index)
	main.call("_refresh_ui")
	var supply_overlay := main.get("district_supply_overlay") as Control
	var supply_access_label := supply_overlay.find_child("DistrictSupplyRuleStrip", true, false) as Label if supply_overlay != null else null
	var supply_chip_row := supply_overlay.find_child("DistrictSupplyShelfChipRail", true, false) as HBoxContainer if supply_overlay != null else null
	var supply_state_rail := supply_overlay.find_child("DistrictSupplyMarketStatusRail", true, false) as HFlowContainer if supply_overlay != null else null
	var supply_list_box := supply_overlay.find_child("DistrictSupplyMarketGrid", true, false) as Container if supply_overlay != null else null
	var supply_preview_box := supply_overlay.find_child("DistrictSupplyPreviewBox", true, false) as VBoxContainer if supply_overlay != null else null
	_expect(supply_overlay != null and supply_overlay.visible, "double-clicking a region opens a visible district side drawer")
	_expect(supply_overlay != null and supply_overlay.has_method("set_supply") and supply_overlay.has_method("debug_snapshot") and supply_overlay.has_signal("supply_action_requested"), "district supply drawer owns one snapshot and aggregate action contract")
	_expect(supply_access_label != null and supply_access_label.text.contains("单击") and supply_access_label.text.contains("预览") and supply_access_label.text.contains("双击") and supply_access_label.text.contains("报价") and supply_access_label.tooltip_text.contains("5个世界秒"), "district card rack explains passive preview and explicit quote intent")
	_expect(supply_chip_row != null and _container_label_text_contains(supply_chip_row, "牌架") and (_container_label_text_contains(supply_chip_row, "可确认") or _container_label_text_contains(supply_chip_row, "仅浏览")) and (_container_label_text_contains(supply_chip_row, "未报价") or _container_label_text_contains(supply_chip_row, "报价锁定") or _container_label_text_contains(supply_chip_row, "报价已过期")) and _container_label_text_contains(supply_chip_row, "单窗口"), "district card rack shows count, access, explicit-quote state, and single-window chips")
	_expect(supply_state_rail != null and _container_label_text_contains(supply_state_rail, "可买") and _container_label_text_contains(supply_state_rail, "弃牌") and _container_label_text_contains(supply_state_rail, "仅看"), "district card rack shows deckbuilder-style market summary chips")
	_expect(supply_list_box != null and (_container_button_text_contains(supply_list_box, "¥") or _container_label_text_contains(supply_list_box, "¥")) and (_container_button_text_contains(supply_list_box, "可购买") or _container_label_text_contains(supply_list_box, "可购买") or _container_button_text_contains(supply_list_box, "需弃牌") or _container_label_text_contains(supply_list_box, "需弃牌") or _container_button_text_contains(supply_list_box, "仅浏览") or _container_label_text_contains(supply_list_box, "仅浏览") or _container_button_text_contains(supply_list_box, "资金不足") or _container_label_text_contains(supply_list_box, "资金不足")), "district market card rows show price and readable purchase state")
	_expect(supply_preview_box != null and _container_button_tooltip_contains(supply_preview_box, "查看总是允许") and (_container_label_text_contains(supply_preview_box, "可购买") or _container_label_text_contains(supply_preview_box, "需弃牌") or _container_label_text_contains(supply_preview_box, "仅浏览") or _container_label_text_contains(supply_preview_box, "资金不足")), "district market preview shows the selected card's purchase conclusion")
	if districts.size() > 1:
		var other_district_index := (district_index + 1) % districts.size()
		main.call("_select_district", other_district_index)
		main.call("_refresh_ui")
		supply_overlay = main.get("district_supply_overlay") as Control
		var supply_title_label := supply_overlay.find_child("DistrictSupplyTitleLabel", true, false) as Label if supply_overlay != null else null
		_expect(supply_overlay != null and supply_overlay.visible and int(main.get("district_supply_open_district")) == district_index and supply_title_label != null and supply_title_label.text.contains("区域牌架"), "district card rack remains pinned to the opened region when the player single-clicks elsewhere")
	var before_cards := _player_card_names(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0)
	var before_cash := _player_cash(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0)
	var activated_market_card: Control = null
	if supply_list_box != null:
		for child in supply_list_box.get_children():
			if child is Control and child.has_method("get_card_name") and str(child.call("get_card_name")) == card_name:
				activated_market_card = child as Control
				break
	_expect(activated_market_card != null and activated_market_card.has_signal("card_activated"), "district supply market renders a reusable card component with an aggregate activation signal")
	if activated_market_card != null:
		activated_market_card.emit_signal("card_activated", card_name)
	var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_cards := _player_card_names(players_after, 0)
	_expect(after_cards.size() >= before_cards.size(), "double-clicking a district card acquires or upgrades a card")
	_expect(_player_has_card_family(after_cards, card_name), "double-click acquisition leaves the card family in the player's hand")
	_expect(_player_cash(players_after, 0) < before_cash, "double-click district card acquisition spends player funds")
	_expect(_player_total_card_spend(players_after, 0) > 0, "district card acquisition records card spend")
	_expect(_player_ledger_contains(players_after, 0, "卡牌支出"), "district card acquisition records an economy ledger spend")
	_clear_player_cooldown(main, 0)


func _verify_globe_projection_interaction(main: Node, district_index: int) -> void:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var map_view := main.get("map_view") as Control
	if map_view == null or district_index < 0 or district_index >= districts.size():
		_expect(false, "globe projection has a map and selected district")
		return
	var district := districts[district_index] as Dictionary
	var center := district.get("center", Vector2.ZERO) as Vector2
	map_view.set("_view_center_m", center)
	map_view.set("_view_zoom", 0.34)
	_expect(bool(map_view.call("_is_globe_mode")), "zoomed-out map switches to globe mode")
	var projected := map_view.call("_project_globe", center) as Dictionary
	_expect(bool(projected.get("visible", false)), "selected region center is visible on the globe front")
	var globe_polygon := map_view.call("_globe_projected_polygon", district.get("polygon", [])) as PackedVector2Array
	_expect(globe_polygon.size() >= 3, "zoomed-out globe keeps the selected region's surface boundary")
	var world_again := map_view.call("_screen_to_globe_world", projected.get("position", Vector2.ZERO)) as Vector2
	_expect(int(map_view.call("_district_at_point", world_again)) == district_index, "click conversion selects the same globe-surface region")
	var focus_target := -1
	var farthest_distance := -1.0
	for i in range(districts.size()):
		if i == district_index:
			continue
		var other_district := districts[i] as Dictionary
		var other_center: Vector2 = other_district.get("center", center) as Vector2
		var distance := float(map_view.call("_surface_distance", center, other_center))
		if distance > farthest_distance:
			farthest_distance = distance
			focus_target = i
	if focus_target >= 0:
		map_view.set("_view_center_m", center)
		map_view.set("_view_zoom", 0.34)
		map_view.set("_target_view_zoom", 0.34)
		main.call("_select_district", focus_target)
		var focus_debug := map_view.call("get_projection_debug_snapshot") as Dictionary
		_expect(int(focus_debug.get("focus_target_district", -1)) == focus_target, "table district jump records the target district for planet rotation")
		_expect(bool(focus_debug.get("focus_rotation_active", false)) or farthest_distance <= 1.0, "table district jump starts a smooth planet rotation when the target is elsewhere")
		map_view.call("_process", 1.0)
		focus_debug = map_view.call("get_projection_debug_snapshot") as Dictionary
		var focused_center: Vector2 = focus_debug.get("view_center_m", center) as Vector2
		var target_district := districts[focus_target] as Dictionary
		var target_center: Vector2 = target_district.get("center", center) as Vector2
		var remaining_distance := float(map_view.call("_surface_distance", focused_center, target_center))
		_expect(remaining_distance <= 2.0, "table district jump rotates the planet center onto the target district")
		var projected_focus := map_view.call("_project_globe", target_center) as Dictionary
		_expect(bool(projected_focus.get("visible", false)), "jumped target district is visible on the front of the globe")
		main.call("_select_district", district_index)
	map_view.set("_view_zoom", 1.0)
	map_view.set("_target_view_zoom", 1.0)
	map_view.queue_redraw()


func _all_districts_have_four_to_five_cards(districts: Array) -> bool:
	for district_variant in districts:
		var district := district_variant as Dictionary
		var choices := _as_array(district.get("card_choices", []))
		if choices.size() < 4 or choices.size() > 5:
			return false
	return not districts.is_empty()


func _all_district_cards_have_sources(districts: Array) -> bool:
	for district_variant in districts:
		var district := district_variant as Dictionary
		var choices := _as_array(district.get("card_choices", []))
		var sources := district.get("card_sources", {}) as Dictionary
		for card_variant in choices:
			if not sources.has(String(card_variant)):
				return false
	return not districts.is_empty()


func _has_monster_card_source(districts: Array) -> bool:
	for district_variant in districts:
		var district := district_variant as Dictionary
		var sources := district.get("card_sources", {}) as Dictionary
		for source_variant in sources.values():
			if String(source_variant).contains("怪兽"):
				return true
	return false


func _players_have_starting_monster_cards(main: Node, players: Array) -> bool:
	for i in range(players.size()):
		var player := players[i] as Dictionary
		var slots := _as_array(player.get("slots", []))
		if slots.is_empty() or slots[0] == null:
			return false
		var skill := slots[0] as Dictionary
		var skill_name := String(skill.get("name", ""))
		if not bool(main.call("_is_monster_card_name", skill_name)):
			return false
		if not bool(skill.get("starter_play_free", false)):
			return false
	return not players.is_empty()


func _players_have_role_cards(main: Node, players: Array) -> bool:
	for i in range(players.size()):
		var player := players[i] as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		if role.is_empty():
			return false
		if String(role.get("kind", "")) != "player_role":
			return false
		if String(role.get("name", "")) == "" or String(role.get("species", "")) == "" or String(role.get("trait", "")) == "":
			return false
		for starter_field in ["starter_monster_index", "starter_monster_name", "starter_monster_card", "starter_hp_bonus", "starter_duration_bonus", "starter_move_multiplier", "starter_fixed_skill_bonus"]:
			if role.has(starter_field):
				return false
		if not role.has("role_index"):
			return false
	return not players.is_empty()


func _role_cards_have_mechanical_passives(players: Array) -> bool:
	for player_variant in players:
		var player := player_variant as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		if String(role.get("passive", "")) == "":
			return false
		var has_mechanical_field := false
		for field_name in ["starting_cash_delta", "starting_cash_bonus", "resource_cash_product", "resource_cash_amount", "bonus_card_product", "monster_upgrade_cash", "intel_city_reveal_charges", "intel_card_trace_charges", "intel_contract_trace_charges", "city_guess_reward_bonus", "card_owner_guess_discount", "card_owner_guess_bonus", "contract_flow_discount", "card_access_extra_hops", "card_access_global", "monster_control_limit_bonus", "military_control_limit_bonus"]:
			if role.has(field_name):
				has_mechanical_field = true
				break
		if not has_mechanical_field:
			return false
	return not players.is_empty()


func _starting_cash_matches_role_bonuses(players: Array) -> bool:
	if players.is_empty():
		return false
	var shared_baseline := 0
	var saw_cash_modifier := false
	for i in range(players.size()):
		var player := players[i] as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		var role_delta := int(role.get("starting_cash_delta", role.get("starting_cash_bonus", 0)))
		var base_cash := int(player.get("base_starting_cash", int(player.get("cash", 0)) - role_delta))
		var start_cash := int(player.get("starting_cash_total", base_cash + role_delta))
		var history := _as_array(player.get("cash_history", []))
		if i == 0:
			shared_baseline = base_cash
		if base_cash != shared_baseline:
			return false
		if start_cash != base_cash + role_delta:
			return false
		if int(player.get("cash", 0)) != start_cash:
			return false
		if history.is_empty() or int(history[0]) != start_cash:
			return false
		saw_cash_modifier = saw_cash_modifier or role_delta != 0
	return shared_baseline > 0 and saw_cash_modifier


func _role_catalog_has_positive_cards(main: Node) -> bool:
	var role_count := int(main.call("_player_role_catalog_size"))
	if role_count < 24:
		return false
	var audit := _diagnostics(main).role_balance_audit()
	if int(audit.get("role_count", 0)) != role_count \
		or not _as_array(audit.get("duplicate_names", [])).is_empty() \
		or not _as_array(audit.get("missing_budget_roles", [])).is_empty() \
		or not _as_array(audit.get("missing_positive_roles", [])).is_empty():
		print("Role codex balance owner audit failed: %s" % str(audit))
		return false
	var names := {}
	var has_supply_role := false
	var has_intel_role := false
	var has_control_role := false
	for role_index in range(role_count):
		var role := main.call("_make_player_role_card", 0, role_index) as Dictionary
		var role_name := String(role.get("name", ""))
		if role_name == "" or names.has(role_name) or String(role.get("species", "")) == "" or String(role.get("passive", "")) == "":
			return false
		names[role_name] = true
		for starter_field in ["starter_monster_index", "starter_monster_name", "starter_monster_card", "starter_hp_bonus", "starter_duration_bonus", "starter_move_multiplier", "starter_fixed_skill_bonus"]:
			if role.has(starter_field):
				return false
		var tags := _as_array(role.get("balance_tags", []))
		if int(role.get("balance_budget", 0)) <= 0 or _as_array(role.get("balance_drivers", [])).is_empty() or tags.is_empty():
			return false
		var snapshot := main.call("_role_codex_public_snapshot", role, role_index, role_count) as Dictionary
		var board := snapshot.get("board", {}) as Dictionary
		if not str(snapshot.get("summary_text", "")).contains(role_name) \
			or str(snapshot.get("route_label", "")).strip_edges() == "" \
			or _as_array(board.get("chips", [])).size() < 2 \
			or _as_array(board.get("kpis", [])).size() != 4 \
			or _as_array(board.get("routes", [])).size() < 6:
			return false
		has_supply_role = has_supply_role or tags.has("supply")
		has_intel_role = has_intel_role or tags.has("intel")
		has_control_role = has_control_role or tags.has("monster") or tags.has("military") or tags.has("counter")
	return names.size() == role_count and has_supply_role and has_intel_role and has_control_role


func _role_card_art_exposes_runtime_triggers(main: Node) -> bool:
	var bonus_card_role := main.call("_make_player_role_card", 0, 0) as Dictionary
	var resource_role := main.call("_make_player_role_card", 0, 1) as Dictionary
	var upgrade_role := main.call("_make_player_role_card", 0, 3) as Dictionary
	var monster_limit_role_index := _role_index_by_name(main, "孪星兽栏同盟")
	var military_limit_role_index := _role_index_by_name(main, "蜂巢防务议会")
	var monster_limit_role := {}
	if monster_limit_role_index >= 0:
		monster_limit_role = main.call("_make_player_role_card", 0, monster_limit_role_index) as Dictionary
	var military_limit_role := {}
	if military_limit_role_index >= 0:
		military_limit_role = main.call("_make_player_role_card", 0, military_limit_role_index) as Dictionary
	var bonus_snapshot := main.call("_role_codex_public_snapshot", bonus_card_role, 0, 1) as Dictionary
	var resource_snapshot := main.call("_role_codex_public_snapshot", resource_role, 0, 1) as Dictionary
	var upgrade_snapshot := main.call("_role_codex_public_snapshot", upgrade_role, 0, 1) as Dictionary
	var monster_limit_snapshot := main.call("_role_codex_public_snapshot", monster_limit_role, 0, 1) as Dictionary
	var military_limit_snapshot := main.call("_role_codex_public_snapshot", military_limit_role, 0, 1) as Dictionary
	var bonus_identity := bonus_snapshot.get("board", {}) as Dictionary
	return String(bonus_identity.get("title_tooltip", "")).contains("公开身份牌") \
		and String(bonus_snapshot.get("economy_line", "")).contains("环晶电池区域购牌+1") \
		and String(resource_snapshot.get("economy_line", "")).contains("深海菌毯城市+¥55/min") \
		and String(upgrade_snapshot.get("economy_line", "")).contains("升兽+¥160") \
		and not monster_limit_role.is_empty() \
		and String(monster_limit_snapshot.get("control_line", "")).contains("怪兽上限2") \
		and not military_limit_role.is_empty() \
		and String(military_limit_snapshot.get("control_line", "")).contains("军队上限2")


func _verify_military_unit_variant_cards(main: Node) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var land_index := _first_terrain_district(districts, "land")
	var ocean_index := _first_terrain_district(districts, "ocean")
	if land_index < 0 or ocean_index < 0:
		return false
	var families := [
		{"base": "行星防卫军", "type": "defense", "domain": "mixed", "gdp": false, "route": false},
		{"base": "制空战斗机", "type": "fighter", "domain": "air", "gdp": true, "route": false},
		{"base": "轨道轰炸机", "type": "bomber", "domain": "air", "gdp": true, "route": true},
		{"base": "重装坦克", "type": "tank", "domain": "land", "gdp": true, "route": false},
		{"base": "导弹阵地", "type": "missile", "domain": "land", "gdp": true, "route": true},
		{"base": "潜航舰队", "type": "submarine", "domain": "sea", "gdp": true, "route": true},
		{"base": "星海战舰", "type": "warship", "domain": "sea", "gdp": true, "route": true},
	]
	for family_variant in families:
		var family := family_variant as Dictionary
		var previous_hp := 0
		var previous_damage := 0
		var previous_duration := 0.0
		for rank in range(1, 5):
			var card_name := "%s%d" % [String(family.get("base", "")), rank]
			var skill := main.call("_make_skill", card_name) as Dictionary
			if skill.is_empty() or String(skill.get("kind", "")) != "military_force":
				return false
			if String(skill.get("military_type", "defense")) != String(family.get("type", "")):
				return false
			if String(skill.get("military_domain", "mixed")) != String(family.get("domain", "")):
				return false
			var hp := int(skill.get("military_hp", 0))
			var damage := int(skill.get("military_damage", 0))
			var duration := float(skill.get("military_duration_seconds", 0.0))
			if hp <= 0 or damage <= 0 or float(skill.get("military_move", 0.0)) <= 0.0 or float(skill.get("military_range", 0.0)) <= 0.0 or duration <= 0.0:
				return false
			if rank > 1 and (hp < previous_hp or damage < previous_damage or duration < previous_duration):
				return false
			previous_hp = hp
			previous_damage = damage
			previous_duration = duration
			if bool(family.get("gdp", false)) and int(skill.get("military_gdp_penalty", 0)) <= 0:
				return false
			if bool(family.get("route", false)) and int(skill.get("military_strike_route_damage", 0)) <= 0:
				return false
			if String(family.get("type", "")) != "defense":
				if _as_array(skill.get("movement_traits", [])).is_empty() or (skill.get("terrain_move_multiplier", {}) as Dictionary).is_empty():
					return false
			var facts := _card_presentation_array(main, skill, "key_rule_facts")
			var facts_text := ""
			for fact_variant in facts:
				facts_text += "%s\n" % String(fact_variant)
			var art_stats := _card_presentation_text(main, skill, "art_stats")
			if not facts_text.contains("军队生命") or not facts_text.contains("军队火力") or not facts_text.contains("军队在场") or not art_stats.contains("HP") or not art_stats.contains("伤"):
				return false
	var fighter := main.call("_make_skill", "制空战斗机1") as Dictionary
	var tank := main.call("_make_skill", "重装坦克1") as Dictionary
	var submarine := main.call("_make_skill", "潜航舰队1") as Dictionary
	if not bool(_military_controller(main).call("can_deploy_at_district", fighter, land_index)) or not bool(_military_controller(main).call("can_deploy_at_district", fighter, ocean_index)):
		return false
	if not bool(_military_controller(main).call("can_deploy_at_district", tank, land_index)) or bool(_military_controller(main).call("can_deploy_at_district", tank, ocean_index)):
		return false
	if bool(_military_controller(main).call("can_deploy_at_district", submarine, land_index)) or not bool(_military_controller(main).call("can_deploy_at_district", submarine, ocean_index)):
		return false
	var tank_land := float(_military_controller(main).call("terrain_move_multiplier", tank, land_index))
	var tank_ocean := float(_military_controller(main).call("terrain_move_multiplier", tank, ocean_index))
	var sub_land := float(_military_controller(main).call("terrain_move_multiplier", submarine, land_index))
	var sub_ocean := float(_military_controller(main).call("terrain_move_multiplier", submarine, ocean_index))
	var fighter_land := float(_military_controller(main).call("terrain_move_multiplier", fighter, land_index))
	var fighter_ocean := float(_military_controller(main).call("terrain_move_multiplier", fighter, ocean_index))
	return tank_land > tank_ocean and sub_ocean > sub_land and fighter_land > 1.0 and fighter_ocean > 1.0


func _verify_military_balance_identity(main: Node) -> bool:
	var report := _military_controller(main).call("force_balance_report") as Dictionary
	var families := report.get("families", {}) as Dictionary
	var issues := _as_array(report.get("issues", []))
	if not bool(report.get("ok", false)):
		print("Military balance audit issues: %s" % " / ".join(issues))
		return false
	for required_type in ["defense", "fighter", "bomber", "tank", "missile", "submarine", "warship"]:
		if not families.has(required_type):
			return false
	var fighter := families["fighter"] as Dictionary
	var bomber := families["bomber"] as Dictionary
	var tank := families["tank"] as Dictionary
	var missile := families["missile"] as Dictionary
	var submarine := families["submarine"] as Dictionary
	var warship := families["warship"] as Dictionary
	var defense := families["defense"] as Dictionary
	var identity_ok := true
	identity_ok = identity_ok and String(report.get("summary", "")).contains("战斗机高机动")
	identity_ok = identity_ok and String(fighter.get("role", "")).contains("高速")
	identity_ok = identity_ok and String(bomber.get("role", "")).contains("GDP")
	identity_ok = identity_ok and String(tank.get("role", "")).contains("耐久")
	identity_ok = identity_ok and float(fighter.get("max_move", 0.0)) > float(bomber.get("max_move", 0.0))
	identity_ok = identity_ok and float(fighter.get("max_move", 0.0)) > float(missile.get("max_move", 0.0))
	identity_ok = identity_ok and int(bomber.get("max_gdp_pressure", 0)) > int(fighter.get("max_gdp_pressure", 0))
	identity_ok = identity_ok and int(bomber.get("max_gdp_pressure", 0)) > int(warship.get("max_gdp_pressure", 0))
	identity_ok = identity_ok and float(missile.get("max_range", 0.0)) > float(bomber.get("max_range", 0.0))
	identity_ok = identity_ok and float(missile.get("max_range", 0.0)) > float(warship.get("max_range", 0.0))
	identity_ok = identity_ok and int(tank.get("max_hp", 0)) > int(fighter.get("max_hp", 0))
	identity_ok = identity_ok and float(tank.get("max_ocean_multiplier", 1.0)) < 0.5
	identity_ok = identity_ok and float(submarine.get("max_ocean_multiplier", 0.0)) > float(submarine.get("max_land_multiplier", 0.0))
	identity_ok = identity_ok and float(warship.get("max_ocean_multiplier", 0.0)) > float(warship.get("max_land_multiplier", 0.0))
	identity_ok = identity_ok and int(bomber.get("max_route_damage", 0)) > 0
	identity_ok = identity_ok and int(missile.get("max_route_damage", 0)) > 0
	identity_ok = identity_ok and int(submarine.get("max_route_damage", 0)) > 0
	identity_ok = identity_ok and int(warship.get("max_route_damage", 0)) > 0
	identity_ok = identity_ok and int(defense.get("max_route_damage", 0)) == 0
	identity_ok = identity_ok and int(fighter.get("max_route_damage", 0)) == 0
	identity_ok = identity_ok and int(tank.get("max_route_damage", 0)) == 0
	if not identity_ok:
		print("Military balance identity report: %s" % str(report))
	return identity_ok


func _verify_ai_military_command_policy(main: Node) -> bool:
	var military := _military_controller(main)
	var ai := _ai_controller(main)
	var saved_ai_enabled := bool(ai.get("ai_card_decision_enabled")) if ai != null else false
	var ok := military != null and ai != null
	var failures := []
	if ai != null:
		ai.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	_reset_route_plan_sandbox_for_test(main)
	ok = ok and _reset_ai_memory_for_test(main, 1)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		_restore_ai_military_command_fixture_for_smoke(main, saved_ai_enabled)
		return false
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		player["cash"] = 6800
		player["action_cooldown"] = 0.0
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var own_district := districts[own_index] as Dictionary
	var own_city := (own_district.get("city", {}) as Dictionary).duplicate(true)
	own_city["active"] = true
	own_city["owner"] = 1
	own_city["name"] = "AI军令防守城"
	own_city["products"] = [{"name": "环晶电池"}]
	own_city["demands"] = ["轨迹墨水"]
	own_city["last_income"] = 720
	own_city["trade_route_damage"] = 2
	own_city["trade_disrupted_routes"] = 2
	own_district["damage"] = 3
	own_district["panic"] = 20
	own_district["products"] = ["环晶电池"]
	own_district["demands"] = ["轨迹墨水"]
	own_district["city"] = own_city
	districts[own_index] = own_district
	var rival_district := districts[rival_index] as Dictionary
	var rival_city := (rival_district.get("city", {}) as Dictionary).duplicate(true)
	rival_city["active"] = true
	rival_city["owner"] = 2
	rival_city["name"] = "AI军令竞品城"
	rival_city["products"] = [{"name": "环晶电池"}]
	rival_city["demands"] = ["星尘香料"]
	rival_city["last_income"] = 920
	rival_city["trade_route_damage"] = 1
	rival_city["trade_disrupted_routes"] = 1
	rival_district["damage"] = 1
	rival_district["panic"] = 18
	rival_district["products"] = ["环晶电池"]
	rival_district["demands"] = ["星尘香料"]
	rival_district["city"] = rival_city
	districts[rival_index] = rival_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var coordinator := _runtime_card_coordinator(main)
	ok = ok and _mark_ai_fixture_regions_active_for_route_owner(coordinator, [own_index, rival_index])
	var route_refresh: Dictionary = coordinator.call("refresh_route_network", true) if coordinator != null else {}
	ok = ok and bool(route_refresh.get("refreshed", false))
	var uid := 77001
	var bomber := main.call("_make_skill", "轨道轰炸机3") as Dictionary
	var unit := {
		"uid": uid,
		"owner": 1,
		"position": own_index,
		"world_position": main.call("_district_center", own_index),
		"cooldown_left": 0.0,
		"public_owner_revealed": false,
	}
	unit = military.call("refresh_unit_from_skill", unit, bomber, own_index) as Dictionary
	unit["range"] = 99999.0
	unit["move"] = 99999.0
	military.call("replace_runtime_state", [unit], uid + 1)
	var actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 2, 1) as Dictionary
	actor["resource_focus"] = ["环晶电池"]
	_monster_controller(main).set("auto_monsters", [actor])
	var guard_command := military.call("make_command_skill", "guard", 3, uid, "轨道轰炸机3") as Dictionary
	var strike_command := military.call("make_command_skill", "strike_district", 3, uid, "轨道轰炸机3") as Dictionary
	var attack_command := military.call("make_command_skill", "attack_monster", 3, uid, "轨道轰炸机3") as Dictionary
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var ai_player := players[1] as Dictionary
	ai_player["slots"] = [guard_command, strike_command, attack_command]
	players[1] = ai_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var production_candidates := ai.call("_ai_card_play_candidates", 1) as Array
	var guard_context := _ai_candidate_for_slot(production_candidates, 0)
	var strike_context := _ai_candidate_for_slot(production_candidates, 1)
	var attack_context := _ai_candidate_for_slot(production_candidates, 2)
	var maximum_bid_budget := 6800 - int(ai.get("AI_CARD_BUY_MIN_CASH_RESERVE"))
	var guard_ok := not guard_context.is_empty() \
		and String(guard_context.get("policy_kind", "")) == "military_command_guard" \
		and String(guard_context.get("military_command_role", "")) == "guard_city" \
		and int(guard_context.get("target_city", -1)) == own_index \
		and int(guard_context.get("target_owner", -1)) == 1 \
		and int(guard_context.get("military_unit_uid", -1)) == uid \
		and _ai_candidate_score_and_budget_valid(guard_context, maximum_bid_budget)
	var strike_ok := not strike_context.is_empty() \
		and String(strike_context.get("policy_kind", "")) == "military_command_strike_district" \
		and String(strike_context.get("military_command_role", "")) == "strike_rival_city" \
		and int(strike_context.get("target_city", -1)) == rival_index \
		and int(strike_context.get("target_owner", -1)) == 2 \
		and int(strike_context.get("military_command_score", 0)) > 0 \
		and _ai_candidate_score_and_budget_valid(strike_context, maximum_bid_budget)
	var attack_ok := not attack_context.is_empty() \
		and String(attack_context.get("policy_kind", "")) == "military_command_attack_monster" \
		and String(attack_context.get("military_command_role", "")) == "attack_threat_monster" \
		and int(attack_context.get("target_slot", -1)) == 0 \
		and int(attack_context.get("resource_match", 0)) > 0 \
		and _ai_candidate_score_and_budget_valid(attack_context, maximum_bid_budget)
	if not guard_ok:
		failures.append("guard context=%s role=%s city=%d owner=%d uid=%d" % [
			str(not guard_context.is_empty()),
			String(guard_context.get("military_command_role", "")),
			int(guard_context.get("target_city", -1)),
			int(guard_context.get("target_owner", -1)),
			int(guard_context.get("military_unit_uid", -1)),
		])
	if not strike_ok:
		failures.append("strike context=%s role=%s city=%d owner=%d score=%d" % [
			str(not strike_context.is_empty()),
			String(strike_context.get("military_command_role", "")),
			int(strike_context.get("target_city", -1)),
			int(strike_context.get("target_owner", -1)),
			int(strike_context.get("military_command_score", 0)),
		])
	if not attack_ok:
		failures.append("attack context=%s role=%s slot=%d resource=%d" % [
			str(not attack_context.is_empty()),
			String(attack_context.get("military_command_role", "")),
			int(attack_context.get("target_slot", -1)),
			int(attack_context.get("resource_match", 0)),
		])
	var queued := bool(ai.call("_ai_queue_play_candidate", 1, strike_context, production_candidates)) if strike_ok else false
	var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var decision_sample := _ai_memory_sample_for_kind(players_after, 1, "匿名出牌")
	var private_decision_metadata_ok := queued \
		and int(decision_sample.get("score", -1)) == int(strike_context.get("score", -2)) \
		and int(decision_sample.get("bid_budget", -1)) == int(strike_context.get("bid_budget", -2))
	var unit_after_first := _military_unit_by_uid(military.call("roster_snapshot", true) as Array, uid)
	var cooldown_after_first := float(unit_after_first.get("cooldown_left", 0.0))
	var candidates_after_queue := ai.call("_ai_card_play_candidates", 1) as Array
	var second_queued := bool(ai.call("_ai_queue_play_candidate", 1, strike_context, production_candidates))
	var unit_after_duplicate := _military_unit_by_uid(military.call("roster_snapshot", true) as Array, uid)
	var duplicate_rejected := candidates_after_queue.is_empty() \
		and not second_queued \
		and cooldown_after_first > 0.0 \
		and is_equal_approx(float(unit_after_duplicate.get("cooldown_left", -1.0)), cooldown_after_first)
	var memory_ok := queued \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "policy_kind", "military_command_strike_district") \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "military_command_role", "strike_rival_city") \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "military_unit_uid", uid)
	var public_roster_text := str(military.call("roster_snapshot", false))
	var private_metadata_stays_private := not public_roster_text.contains("ai_utility_score") \
		and not public_roster_text.contains("ai_bid_budget") \
		and not public_roster_text.contains("military_command_strike_district") \
		and not public_roster_text.contains("strike_rival_city")
	if not memory_ok:
		failures.append("memory queued=%s" % str(queued))
	if not private_decision_metadata_ok:
		failures.append("private decision metadata score=%d/%d budget=%d/%d" % [int(decision_sample.get("score", -1)), int(strike_context.get("score", -2)), int(decision_sample.get("bid_budget", -1)), int(strike_context.get("bid_budget", -2))])
	if not duplicate_rejected:
		failures.append("duplicate candidate remained or command cooldown changed twice")
	if not private_metadata_stays_private:
		failures.append("private AI command metadata entered the public military roster")
	var restored := _restore_ai_military_command_fixture_for_smoke(main, saved_ai_enabled)
	if not failures.is_empty():
		print("AI military command policy failures: %s" % " / ".join(failures))
	return ok and guard_ok and strike_ok and attack_ok and private_decision_metadata_ok and duplicate_rejected and memory_ok and private_metadata_stays_private and restored


func _ai_candidate_for_slot(candidates: Array, slot_index: int) -> Dictionary:
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and int((candidate_variant as Dictionary).get("slot_index", -1)) == slot_index:
			return (candidate_variant as Dictionary).duplicate(true)
	return {}


func _ai_candidate_score_and_budget_valid(candidate: Dictionary, maximum_bid_budget: int) -> bool:
	var bid_budget := int(candidate.get("bid_budget", -1))
	return int(candidate.get("score", 0)) > 0 and bid_budget >= 0 and bid_budget <= maximum_bid_budget


func _ai_memory_sample_for_kind(players: Array, player_index: int, kind: String) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {}
	var memory: Dictionary = (players[player_index] as Dictionary).get("ai_memory", {})
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if sample_variant is Dictionary and String((sample_variant as Dictionary).get("kind", "")) == kind:
			return (sample_variant as Dictionary).duplicate(true)
	return {}


func _military_unit_by_uid(roster: Array, uid: int) -> Dictionary:
	for unit_variant in roster:
		if unit_variant is Dictionary and int((unit_variant as Dictionary).get("uid", 0)) == uid:
			return (unit_variant as Dictionary).duplicate(true)
	return {}


func _mark_ai_fixture_regions_active_for_route_owner(coordinator: Node, legacy_indices: Array) -> bool:
	if coordinator == null or not coordinator.has_method("region_infrastructure_runtime_controller"):
		return false
	var region_owner := coordinator.call("region_infrastructure_runtime_controller") as Node
	if region_owner == null or not region_owner.has_method("to_save_data") or not region_owner.has_method("apply_save_data"):
		return false
	var owner_state := region_owner.call("to_save_data") as Dictionary
	var regions := _as_array(owner_state.get("regions", [])).duplicate(true)
	var matched := 0
	for region_index in range(regions.size()):
		if not (regions[region_index] is Dictionary):
			continue
		var region := (regions[region_index] as Dictionary).duplicate(true)
		if not legacy_indices.has(int(region.get("legacy_index", -1))):
			continue
		region["legacy_city_active"] = true
		regions[region_index] = region
		matched += 1
	owner_state["regions"] = regions
	var applied := region_owner.call("apply_save_data", owner_state) as Dictionary
	return matched == legacy_indices.size() and bool(applied.get("applied", false))


func _first_purchasable_empty_land_district_for_ai_fixture(main: Node, excluded: Array = []) -> int:
	var coordinator := _runtime_card_coordinator(main)
	if coordinator == null or not coordinator.has_method("card_market_listing_availability"):
		return -1
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	for district_index in range(districts.size()):
		if excluded.has(district_index) or not (districts[district_index] is Dictionary):
			continue
		var district := districts[district_index] as Dictionary
		if String(district.get("terrain", "")) != "land" or bool(district.get("destroyed", false)) or not (district.get("city", {}) as Dictionary).is_empty():
			continue
		var availability := coordinator.call("card_market_listing_availability", district_index) as Dictionary
		if bool(availability.get("purchasable", false)):
			return district_index
	return -1


func _restore_ai_military_command_fixture_for_smoke(main: Node, ai_enabled: bool) -> bool:
	main.call("_new_game")
	var ai := _ai_controller(main)
	if ai != null:
		ai.set("ai_card_decision_enabled", ai_enabled)
	var military := _military_controller(main)
	var roster: Array = military.call("roster_snapshot", true) if military != null and military.has_method("roster_snapshot") else []
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var ai_memory: Dictionary = (players[1] as Dictionary).get("ai_memory", {}) if players.size() > 1 and players[1] is Dictionary else {}
	var decision_samples := _as_array(ai_memory.get("decision_samples", []))
	return military != null \
		and ai != null \
		and bool(ai.get("ai_card_decision_enabled")) == ai_enabled \
		and roster.is_empty() \
		and players.size() == int(main.get("configured_player_count")) \
		and decision_samples.is_empty() \
		and _as_array(main.get("card_resolution_queue")).is_empty() \
		and _as_array(main.get("next_card_resolution_queue")).is_empty() \
		and (main.get("active_card_resolution") as Dictionary).is_empty()


func _verify_ai_military_force_deploy_policy(main: Node) -> bool:
	var ai := _ai_controller(main)
	var military := _military_controller(main)
	var saved_ai_enabled := bool(ai.get("ai_card_decision_enabled")) if ai != null else false
	var ok := ai != null and military != null
	var failures := []
	main.call("_new_game")
	ai = _ai_controller(main)
	military = _military_controller(main)
	if ai != null:
		ai.set("ai_card_decision_enabled", true)
	_monster_controller(main).set("auto_monsters", [])
	ok = ok and _reset_ai_memory_for_test(main, 1)
	var own_index := _first_purchasable_empty_land_district_for_ai_fixture(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		_restore_ai_military_command_fixture_for_smoke(main, saved_ai_enabled)
		return false
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		player["cash"] = 7200
		player["action_cooldown"] = 0.0
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var own_district := districts[own_index] as Dictionary
	var own_city := (own_district.get("city", {}) as Dictionary).duplicate(true)
	own_city["active"] = true
	own_city["owner"] = 1
	own_city["name"] = "AI军队护航城"
	own_city["products"] = [{"name": "重力陶瓷"}, {"name": "太阳鳞片"}, {"name": "离岸水晶"}]
	own_city["demands"] = ["轨迹墨水", "星尘香料"]
	own_city["warehouse_stockpile_count"] = 3
	own_city["warehouse_stockpile_units"] = 3
	own_city["warehouse_stockpile_products"] = ["重力陶瓷", "太阳鳞片", "离岸水晶"]
	own_city["last_income"] = 980
	own_city["trade_route_damage"] = 2
	own_city["trade_disrupted_routes"] = 2
	own_district["damage"] = 4
	own_district["panic"] = 26
	own_district["products"] = ["重力陶瓷", "太阳鳞片", "离岸水晶"]
	own_district["demands"] = ["轨迹墨水", "星尘香料"]
	own_district["card_choices"] = ["轨道轰炸机1", "行星防卫军1"]
	own_district["city"] = own_city
	districts[own_index] = own_district
	var rival_district := districts[rival_index] as Dictionary
	var rival_city := (rival_district.get("city", {}) as Dictionary).duplicate(true)
	rival_city["active"] = true
	rival_city["owner"] = 2
	rival_city["name"] = "AI军队压制城"
	rival_city["products"] = [{"name": "环晶电池"}, {"name": "海底黑油"}]
	rival_city["demands"] = ["太阳鳞片", "星尘香料"]
	rival_city["last_income"] = 1180
	rival_city["trade_route_damage"] = 1
	rival_city["trade_disrupted_routes"] = 1
	rival_city["warehouse_stockpile_count"] = 2
	rival_city["warehouse_stockpile_units"] = 5
	rival_city["warehouse_stockpile_products"] = ["环晶电池", "太阳鳞片"]
	rival_district["damage"] = 1
	rival_district["panic"] = 12
	rival_district["products"] = ["环晶电池", "海底黑油"]
	rival_district["demands"] = ["太阳鳞片", "星尘香料"]
	rival_district["city"] = rival_city
	districts[rival_index] = rival_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var coordinator := _runtime_card_coordinator(main)
	ok = ok and _mark_ai_fixture_regions_active_for_route_owner(coordinator, [own_index, rival_index])
	var route_refresh: Dictionary = coordinator.call("refresh_route_network", true) if coordinator != null else {}
	ok = ok and bool(route_refresh.get("refreshed", false))
	var defender := _runtime_card_definition(main, "行星防卫军1")
	var bomber := _runtime_card_definition(main, "轨道轰炸机1")
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var ai_player := players[1] as Dictionary
	ai_player["slots"] = [defender, bomber]
	players[1] = ai_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var production_candidates := ai.call("_ai_card_play_candidates", 1) as Array
	var guard_context := _ai_candidate_for_slot(production_candidates, 0)
	var strike_context := _ai_candidate_for_slot(production_candidates, 1)
	var maximum_bid_budget := 7200 - int(ai.get("AI_CARD_BUY_MIN_CASH_RESERVE"))
	var guard_ok := not guard_context.is_empty() \
		and String(guard_context.get("policy_kind", "")) == "military_force_guard_own_city" \
		and String(guard_context.get("military_deploy_role", "")) == "guard_own_city" \
		and int(guard_context.get("target_city", -1)) == own_index \
		and int(guard_context.get("target_owner", -1)) == 1 \
		and int(guard_context.get("military_deploy_score", 0)) > 0 \
		and _ai_candidate_score_and_budget_valid(guard_context, maximum_bid_budget)
	var strike_ok := not strike_context.is_empty() \
		and String(strike_context.get("policy_kind", "")) == "military_force_strike_rival_city" \
		and String(strike_context.get("military_deploy_role", "")) == "strike_rival_city" \
		and int(strike_context.get("target_city", -1)) == rival_index \
		and int(strike_context.get("target_owner", -1)) == 2 \
		and int(strike_context.get("military_deploy_score", 0)) > 0 \
		and _ai_candidate_score_and_budget_valid(strike_context, maximum_bid_budget)
	if not guard_ok:
		failures.append("guard context=%s role=%s city=%d owner=%d score=%d" % [
			str(not guard_context.is_empty()),
			String(guard_context.get("military_deploy_role", "")),
			int(guard_context.get("target_city", -1)),
			int(guard_context.get("target_owner", -1)),
			int(guard_context.get("military_deploy_score", 0)),
		])
	if not strike_ok:
		failures.append("strike context=%s role=%s city=%d owner=%d score=%d" % [
			str(not strike_context.is_empty()),
			String(strike_context.get("military_deploy_role", "")),
			int(strike_context.get("target_city", -1)),
			int(strike_context.get("target_owner", -1)),
			int(strike_context.get("military_deploy_score", 0)),
		])
	var actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 2, 1) as Dictionary
	actor["resource_focus"] = ["太阳鳞片"]
	_monster_controller(main).set("auto_monsters", [actor])
	var buy_candidates := ai.call("_ai_card_buy_candidates", 1) as Array
	var purchase_ok := false
	for candidate_variant in buy_candidates:
		var candidate := candidate_variant as Dictionary
		if String(candidate.get("card_name", "")) != "轨道轰炸机1":
			continue
		purchase_ok = String(candidate.get("military_deploy_role", "")) == "strike_rival_city" \
			and int(candidate.get("military_deploy_district", -1)) == rival_index \
			and int(candidate.get("district", -1)) == own_index \
			and int(candidate.get("military_deploy_score", 0)) > 0 \
			and int(candidate.get("score", 0)) > 0 \
			and int(candidate.get("price", 0)) > 0
		if purchase_ok:
			break
	if not purchase_ok:
		failures.append("purchase metadata missing or not separated from buy district")
	var queued := bool(ai.call("_ai_queue_play_candidate", 1, strike_context, production_candidates)) if strike_ok else false
	var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var decision_sample := _ai_memory_sample_for_kind(players_after, 1, "匿名出牌")
	var private_decision_metadata_ok := queued \
		and int(decision_sample.get("score", -1)) == int(strike_context.get("score", -2)) \
		and int(decision_sample.get("bid_budget", -1)) == int(strike_context.get("bid_budget", -2))
	var roster_after_first := military.call("roster_snapshot", true) as Array
	var deployed_unit := roster_after_first[0] as Dictionary if roster_after_first.size() == 1 and roster_after_first[0] is Dictionary else {}
	var deployment_result_ok := roster_after_first.size() == 1 \
		and int(deployed_unit.get("owner", -1)) == 1 \
		and int(deployed_unit.get("position", -1)) == rival_index \
		and String(deployed_unit.get("military_type", "")) == "bomber"
	var candidates_after_queue := ai.call("_ai_card_play_candidates", 1) as Array
	var strike_consumed := _ai_candidate_for_slot(candidates_after_queue, 1).is_empty()
	var second_policy_action := String(ai.call("_ai_execute_card_turn", 1, true))
	var roster_after_duplicate := military.call("roster_snapshot", true) as Array
	var duplicate_rejected := strike_consumed and second_policy_action != "play" and roster_after_duplicate.size() == roster_after_first.size() \
		and int(_military_unit_by_uid(roster_after_duplicate, int(deployed_unit.get("uid", 0))).get("uid", 0)) == int(deployed_unit.get("uid", -1))
	var memory_ok := queued \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "policy_kind", "military_force_strike_rival_city") \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "military_deploy_role", "strike_rival_city") \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "military_deploy_terrain", "land")
	var public_roster_text := str(military.call("roster_snapshot", false))
	var private_metadata_stays_private := not public_roster_text.contains("ai_utility_score") \
		and not public_roster_text.contains("ai_bid_budget") \
		and not public_roster_text.contains("military_force_strike_rival_city") \
		and not public_roster_text.contains("strike_rival_city")
	if not memory_ok:
		failures.append("memory queued=%s" % str(queued))
	if not private_decision_metadata_ok:
		failures.append("private decision metadata score=%d/%d budget=%d/%d" % [int(decision_sample.get("score", -1)), int(strike_context.get("score", -2)), int(decision_sample.get("bid_budget", -1)), int(strike_context.get("bid_budget", -2))])
	if not deployment_result_ok:
		failures.append("deployment result count=%d owner=%d position=%d type=%s" % [roster_after_first.size(), int(deployed_unit.get("owner", -1)), int(deployed_unit.get("position", -1)), String(deployed_unit.get("military_type", ""))])
	if not duplicate_rejected:
		var roster_after_duplicate_ids := []
		for unit_variant in roster_after_duplicate:
			if unit_variant is Dictionary:
				var unit := unit_variant as Dictionary
				roster_after_duplicate_ids.append("%d:%s@%d" % [int(unit.get("uid", -1)), String(unit.get("military_type", "")), int(unit.get("position", -1))])
		failures.append("consumed force card repeated through the AI policy or changed authoritative roster (strike_consumed=%s second_action=%s roster=%d->%d uid=%d after=%s)" % [
			str(strike_consumed),
			second_policy_action,
			roster_after_first.size(),
			roster_after_duplicate.size(),
			int(deployed_unit.get("uid", -1)),
			str(roster_after_duplicate_ids),
		])
	if not private_metadata_stays_private:
		failures.append("private AI deployment metadata entered the public military roster")
	var restored := _restore_ai_military_command_fixture_for_smoke(main, saved_ai_enabled)
	if not failures.is_empty():
		print("AI military force deploy policy failures: %s" % " / ".join(failures))
	return ok and guard_ok and strike_ok and memory_ok and purchase_ok and private_decision_metadata_ok and deployment_result_ok and duplicate_rejected and private_metadata_stays_private and restored


func _verify_ai_product_futures_policy(main: Node) -> bool:
	var saved := {
		"players": _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true),
		"districts": _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true),
		"auto_monsters": _as_array(main.get("auto_monsters")).duplicate(true),
		"product_market": _product_market_for_test(main).duplicate(true),
		"selected_trade_product": String(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product),
		"active_card_resolution": (main.get("active_card_resolution") as Dictionary).duplicate(true),
		"card_resolution_queue": _as_array(main.get("card_resolution_queue")).duplicate(true),
		"next_card_resolution_queue": _as_array(main.get("next_card_resolution_queue")).duplicate(true),
		"card_resolution_batch_locked": main.get("card_resolution_batch_locked") == true,
		"card_resolution_auction_open": main.get("card_resolution_auction_open") == true,
	}
	var saved_ai_enabled: bool = main.get("ai_card_decision_enabled") == true
	var ok := true
	var failures := []
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = "环晶电池"
	_reset_route_plan_sandbox_for_test(main)
	ok = ok and _reset_ai_memory_for_test(main, 1)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = saved.players
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = saved.districts
		main.set("auto_monsters", saved.auto_monsters)
		_replace_product_market_for_test(main, saved.product_market)
		main.set("ai_card_decision_enabled", saved_ai_enabled)
		return false
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		player["cash"] = 7200
		player["action_cooldown"] = 0.0
		if player_index == 1:
			var memory := _ai_controller(main).call("_empty_ai_memory") as Dictionary
			memory["economic_focus_product"] = "环晶电池"
			memory["economic_focus_score"] = 900
			memory["strategy_intent"] = "grow_focus"
			memory["strategy_score"] = 820
			memory["route_plan_product"] = "环晶电池"
			memory["route_plan_stage"] = "strengthen_route"
			memory["route_plan_score"] = 760
			player["ai_memory"] = memory
			player["slots"] = [
				main.call("_make_skill", "商品看涨1"),
				main.call("_make_skill", "商品看跌1"),
				main.call("_make_skill", "港仓囤货1"),
			]
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var own_created := CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI期货港仓城")
	var rival_created := CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI期货竞品城")
	ok = ok and own_created and rival_created
	ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池")
	ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "轨迹墨水")
	_runtime_coordinator(main).call("refresh_route_network", true)
	_set_product_market_focus_for_test(main, "环晶电池")
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var supply_district := districts[own_index] as Dictionary
	supply_district["card_choices"] = ["商品看涨1", "商品看跌1", "港仓囤货1"]
	districts[own_index] = supply_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 1, 1) as Dictionary
	main.set("auto_monsters", [actor])
	var long_skill := main.call("_make_skill", "商品看涨1") as Dictionary
	var long_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, long_skill) as Dictionary
	var stockpile_skill := main.call("_make_skill", "港仓囤货1") as Dictionary
	var stockpile_context := _ai_controller(main).call("_ai_card_play_context", 1, 2, stockpile_skill) as Dictionary
	var long_ok := not long_context.is_empty() \
		and String(long_context.get("policy_kind", "")) == "product_futures_up" \
		and String(long_context.get("product", "")) == "环晶电池" \
		and String(long_context.get("futures_direction", "")) == "up" \
		and int(long_context.get("futures_signal", 0)) > 0 \
		and int(long_context.get("generic_effect_bonus", 0)) > 0
	var stockpile_ok := not stockpile_context.is_empty() \
		and String(stockpile_context.get("policy_kind", "")) == "product_futures_stockpile" \
		and int(stockpile_context.get("district", -1)) == own_index \
		and int(stockpile_context.get("futures_warehouse_city", -1)) == own_index \
		and bool(stockpile_context.get("futures_warehouse_required", false)) \
		and int(stockpile_context.get("futures_stockpile_units", 0)) >= 2
	if not long_ok:
		failures.append("long context=%s policy=%s product=%s signal=%d generic=%d" % [
			str(not long_context.is_empty()),
			String(long_context.get("policy_kind", "")),
			String(long_context.get("product", "")),
			int(long_context.get("futures_signal", 0)),
			int(long_context.get("generic_effect_bonus", 0)),
		])
	if not stockpile_ok:
		failures.append("stockpile context=%s district=%d warehouse=%d units=%d" % [
			str(not stockpile_context.is_empty()),
			int(stockpile_context.get("district", -1)),
			int(stockpile_context.get("futures_warehouse_city", -1)),
			int(stockpile_context.get("futures_stockpile_units", 0)),
		])
	var market := _product_market_for_test(main)
	var short_entry := (market.get("环晶电池", {}) as Dictionary).duplicate(true)
	short_entry["price"] = 92
	short_entry["base_price"] = 120
	short_entry["demand"] = 1
	short_entry["supply"] = 13
	short_entry["temporary_demand_pressure"] = 0
	short_entry["temporary_supply_pressure"] = 7
	short_entry["volatility"] = 5
	market["环晶电池"] = short_entry
	_replace_product_market_for_test(main, market)
	var short_skill := main.call("_make_skill", "商品看跌1") as Dictionary
	var short_context := _ai_controller(main).call("_ai_card_play_context", 1, 1, short_skill) as Dictionary
	var short_ok := not short_context.is_empty() \
		and String(short_context.get("policy_kind", "")) == "product_futures_down" \
		and String(short_context.get("product", "")) == "环晶电池" \
		and String(short_context.get("futures_direction", "")) == "down" \
		and int(short_context.get("futures_market_score", 0)) > 0 \
		and int(short_context.get("generic_effect_bonus", 0)) > 0
	if not short_ok:
		failures.append("short context=%s policy=%s product=%s market=%d generic=%d" % [
			str(not short_context.is_empty()),
			String(short_context.get("policy_kind", "")),
			String(short_context.get("product", "")),
			int(short_context.get("futures_market_score", 0)),
			int(short_context.get("generic_effect_bonus", 0)),
		])
	var buy_candidates := _ai_controller(main).call("_ai_card_buy_candidates", 1) as Array
	var buy_long := {}
	var buy_stockpile := {}
	for candidate_variant in buy_candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if String(candidate.get("card_name", "")) == "商品看涨1":
			if buy_long.is_empty() or int(candidate.get("district", -1)) == own_index:
				buy_long = candidate
		elif String(candidate.get("card_name", "")) == "港仓囤货1":
			if buy_stockpile.is_empty() or int(candidate.get("futures_warehouse_city", -1)) == own_index:
				buy_stockpile = candidate
	var buy_ok := not buy_long.is_empty() \
		and int(buy_long.get("district", -1)) >= 0 \
		and int(buy_long.get("futures_play_district", -1)) >= 0 \
		and String(buy_long.get("policy_kind", "")) == "product_futures_up" \
		and int(buy_long.get("futures_signal", 0)) > 0 \
		and not buy_stockpile.is_empty() \
		and String(buy_stockpile.get("policy_kind", "")) == "product_futures_stockpile" \
		and int(buy_stockpile.get("futures_warehouse_city", -1)) == own_index
	if not buy_ok:
		failures.append("buy long=%s stockpile=%s long_policy=%s stock_policy=%s long_signal=%d warehouse=%d" % [
			str(not buy_long.is_empty()),
			str(not buy_stockpile.is_empty()),
			String(buy_long.get("policy_kind", "")),
			String(buy_stockpile.get("policy_kind", "")),
			int(buy_long.get("futures_signal", 0)),
			int(buy_stockpile.get("futures_warehouse_city", -1)),
		])
	var play_candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
	var stockpile_choice := _find_ai_play_candidate_by_card(play_candidates, "港仓囤货1")
	var queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, stockpile_choice, play_candidates)) if not stockpile_choice.is_empty() else false
	var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var memory_ok := queued \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "policy_kind", "product_futures_stockpile") \
		and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "futures_warehouse_city", own_index)
	if not memory_ok:
		failures.append("memory queued=%s choice=%s" % [str(queued), str(not stockpile_choice.is_empty())])
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = saved.players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = saved.districts
	main.set("auto_monsters", saved.auto_monsters)
	_replace_product_market_for_test(main, saved.product_market)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = saved.selected_trade_product
	main.set("active_card_resolution", saved.active_card_resolution)
	main.set("card_resolution_queue", saved.card_resolution_queue)
	main.set("next_card_resolution_queue", saved.next_card_resolution_queue)
	main.set("card_resolution_batch_locked", saved.card_resolution_batch_locked)
	main.set("card_resolution_auction_open", saved.card_resolution_auction_open)
	var restore_result := OK
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	if not failures.is_empty():
		print("AI product futures policy failures: %s" % " / ".join(failures))
	return ok and long_ok and short_ok and stockpile_ok and buy_ok and memory_ok and restore_result == OK


func _verify_product_futures_terms_catalog(main: Node) -> bool:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	if controller == null or not controller.has_method("all_futures_terms"):
		print("Product futures balance audit failure: runtime controller or terms API missing")
		return false
	var terms: Array = controller.call("all_futures_terms")
	var ok := terms.size() == 12
	var warehouse_count := 0
	for terms_variant in terms:
		if not (terms_variant is Dictionary):
			ok = false
			continue
		var entry := terms_variant as Dictionary
		ok = ok and str(entry.get("terms_version", "")) == "v0.4" and float(entry.get("duration_seconds", 0.0)) > 0.0
		ok = ok and int(entry.get("margin_cash", 0)) > 0 and int(entry.get("maximum_gain", 0)) > 0 and int(entry.get("maximum_loss", 0)) > 0
		if bool(entry.get("requires_warehouse", false)):
			warehouse_count += 1
			ok = ok and int(entry.get("units", 0)) >= 2
		else:
			ok = ok and int(entry.get("units", 0)) == 1
	ok = ok and warehouse_count == 4
	if not ok:
		print("Product futures terms audit failure: count=%d warehouse=%d" % [terms.size(), warehouse_count])
	return ok


func _verify_temporary_economy_duration_seconds(main: Node) -> bool:
	var report := _diagnostics(main).temporary_economy_seconds_audit()
	var violations := _as_array(report.get("violations", []))
	if not violations.is_empty():
		print("Temporary economy duration audit failures: %s" % " / ".join(violations))
	return violations.is_empty() and int(report.get("seconds_card_count", 0)) >= 30 and int(report.get("compatibility_mirror_count", 0)) >= 20


func _verify_random_ai_roles_resolve_unique(main: Node) -> bool:
	var previous_player_count := int(main.get("configured_player_count"))
	var previous_ai_count := int(main.get("configured_ai_player_count"))
	var previous_role_indices := _as_array(main.get("configured_role_indices")).duplicate(true)
	var ok := true
	var random_index := -1
	main.set("configured_player_count", 8)
	main.set("configured_ai_player_count", 7)
	main.set("configured_role_indices", [0, random_index, random_index, random_index, random_index, random_index, random_index, random_index])
	main.call("_ensure_configured_role_indices")
	var configured := _as_array(main.get("configured_role_indices"))
	ok = ok and configured.size() >= 8 and int(configured[1]) == random_index and int(configured[7]) == random_index
	main.call("_new_game")
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var used := {}
	ok = ok and players.size() == 8
	for player_variant in players:
		var player := player_variant as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		var role_index := int(role.get("role_index", -1))
		if role_index < 0 or used.has(role_index):
			ok = false
			break
		used[role_index] = true
		if String(role.get("name", "")) == "随机角色":
			ok = false
			break
	var restored := _restore_role_setup_for_smoke(main, previous_player_count, previous_ai_count, previous_role_indices)
	return ok and restored


func _restore_role_setup_for_smoke(main: Node, player_count: int, ai_count: int, role_indices: Array) -> bool:
	main.set("configured_player_count", player_count)
	main.set("configured_ai_player_count", ai_count)
	main.set("configured_role_indices", role_indices.duplicate(true))
	main.call("_ensure_configured_role_indices")
	main.call("_new_game")
	var restored_roles := _as_array(main.get("configured_role_indices"))
	return int(main.get("configured_player_count")) == player_count \
		and int(main.get("configured_ai_player_count")) == ai_count \
		and restored_roles.size() >= player_count


func _role_index_array_is_unique(indices: Array, seat_count: int, allow_random: bool = false) -> bool:
	if indices.size() < seat_count:
		return false
	var used := {}
	for seat in range(seat_count):
		var role_index := int(indices[seat])
		if role_index == -1 and allow_random:
			continue
		if role_index < 0 or used.has(role_index):
			return false
		used[role_index] = true
	return true


func _verify_role_selection_and_budget_audit(main: Node) -> bool:
	var previous_player_count := int(main.get("configured_player_count"))
	var previous_ai_count := int(main.get("configured_ai_player_count"))
	var previous_role_indices := _as_array(main.get("configured_role_indices")).duplicate(true)
	var ok := true
	var role_count := int(main.call("_player_role_catalog_size"))
	ok = ok and role_count >= 24
	var audit := _diagnostics(main).role_balance_audit()
	var duplicate_names := _as_array(audit.get("duplicate_names", []))
	var missing_budget_roles := _as_array(audit.get("missing_budget_roles", []))
	var missing_positive_roles := _as_array(audit.get("missing_positive_roles", []))
	var band_counts := audit.get("budget_band_counts", {}) as Dictionary
	ok = ok and int(audit.get("role_count", 0)) == role_count
	ok = ok and duplicate_names.is_empty()
	ok = ok and missing_budget_roles.is_empty()
	ok = ok and missing_positive_roles.is_empty()
	ok = ok and int(audit.get("budget_min", 0)) > 0
	ok = ok and int(audit.get("budget_max", 0)) > int(audit.get("budget_min", 0))
	ok = ok and float(audit.get("budget_average", 0.0)) > 0.0
	ok = ok and band_counts.size() >= 2
	var summary := _diagnostics(main).role_balance_audit_summary(audit)
	ok = ok and summary.contains("角色预算审计") and summary.contains("强度")
	var saw_economy := false
	var saw_supply := false
	var saw_intel := false
	var saw_control := false
	for role_index in range(role_count):
		var role := main.call("_make_player_role_card", role_index, role_index) as Dictionary
		var budget_points := int(role.get("balance_budget", 0))
		var band := String(role.get("balance_band", ""))
		var drivers := _as_array(role.get("balance_drivers", []))
		var tags := _as_array(role.get("balance_tags", []))
		ok = ok and budget_points > 0 and band != "" and not drivers.is_empty() and not tags.is_empty()
		ok = ok and String(role.get("balance_summary", "")).contains("强度预算")
		for starter_field in ["starter_monster_index", "starter_monster_name", "starter_monster_card", "starter_hp_bonus", "starter_duration_bonus", "starter_move_multiplier", "starter_fixed_skill_bonus"]:
			ok = ok and not role.has(starter_field)
		saw_economy = saw_economy or tags.has("economy") or tags.has("opening")
		saw_supply = saw_supply or tags.has("supply")
		saw_intel = saw_intel or tags.has("intel")
		saw_control = saw_control or tags.has("monster") or tags.has("military") or tags.has("counter")
	ok = ok and saw_economy and saw_supply and saw_intel and saw_control
	var seat_count := mini(8, role_count)
	var duplicate_config := []
	for duplicate_seat in range(seat_count):
		duplicate_config.append(0)
	main.set("configured_player_count", seat_count)
	main.set("configured_ai_player_count", maxi(0, seat_count - 1))
	main.set("configured_role_indices", duplicate_config)
	main.call("_ensure_configured_role_indices")
	ok = ok and _role_index_array_is_unique(_as_array(main.get("configured_role_indices")), seat_count, false)
	var random_config := [0]
	for random_seat in range(1, seat_count):
		random_config.append(-1)
	main.set("configured_role_indices", random_config)
	main.call("_ensure_configured_role_indices")
	ok = ok and _role_index_array_is_unique(_as_array(main.get("configured_role_indices")), seat_count, true)
	var resolved := main.call("_resolve_configured_role_indices_for_run") as Array
	ok = ok and _role_index_array_is_unique(resolved, seat_count, false)
	var restored := _restore_role_setup_for_smoke(main, previous_player_count, previous_ai_count, previous_role_indices)
	return ok and restored


func _role_index_by_name(main: Node, role_name: String) -> int:
	for role_index in range(int(main.call("_player_role_catalog_size"))):
		var role := main.call("_make_player_role_card", 0, role_index) as Dictionary
		if String(role.get("name", "")) == role_name:
			return role_index
	return -1


func _set_player_role_for_test(main: Node, player_index: int, role_name: String) -> bool:
	var role_index := _role_index_by_name(main, role_name)
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	if role_index < 0 or player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	player["role_card"] = main.call("_make_player_role_card", player_index, role_index)
	players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	return true


func _set_city_goods_for_test(main: Node, district_index: int, product_name: String, demand_name: String) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	if district_index < 0 or district_index >= districts.size():
		return false
	var district := districts[district_index] as Dictionary
	var city := district.get("city", {}) as Dictionary
	if city.is_empty():
		return false
	city["products"] = [{"name": product_name, "level": 1}]
	city["demands"] = [demand_name]
	district["products"] = [product_name]
	district["demands"] = [demand_name]
	district["city"] = city
	districts[district_index] = district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	return true


func _set_city_products_and_demands_for_test(main: Node, district_index: int, product_names: Array, demand_names: Array, level: int = 2) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	if district_index < 0 or district_index >= districts.size():
		return false
	var district := districts[district_index] as Dictionary
	var city := district.get("city", {}) as Dictionary
	if city.is_empty():
		return false
	var product_entries := []
	var district_products := []
	for product_variant in product_names:
		var product_name := String(product_variant)
		if product_name == "" or district_products.has(product_name):
			continue
		district_products.append(product_name)
		product_entries.append({"name": product_name, "level": maxi(1, level)})
	var district_demands := []
	for demand_variant in demand_names:
		var demand_name := String(demand_variant)
		if demand_name == "" or district_demands.has(demand_name):
			continue
		district_demands.append(demand_name)
	city["products"] = product_entries
	city["demands"] = district_demands
	district["products"] = district_products
	district["demands"] = district_demands
	district["city"] = city
	districts[district_index] = district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	return true


func _set_district_goods_for_test(main: Node, district_index: int, product_name: String, demand_name: String) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	if district_index < 0 or district_index >= districts.size():
		return false
	var district := districts[district_index] as Dictionary
	district["products"] = [product_name]
	district["demands"] = [demand_name]
	districts[district_index] = district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	return true


func _reset_ai_memory_for_test(main: Node, player_index: int) -> bool:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	player["ai_memory"] = _ai_controller(main).call("_empty_ai_memory")
	players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	return true


func _reset_route_plan_sandbox_for_test(main: Node) -> void:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	for i in range(districts.size()):
		if not (districts[i] is Dictionary):
			continue
		var district := districts[i] as Dictionary
		district["city"] = {}
		if String(district.get("terrain", "")) == "land":
			district["destroyed"] = false
			district["damage"] = 0
			district["panic"] = 0
			district["hp"] = 120
			district["transport_score"] = 1.0
			district["products"] = ["深海菌毯"]
			district["demands"] = ["星尘香料"]
		districts[i] = district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	main.set("auto_monsters", [])


func _set_product_market_focus_for_test(main: Node, focus_product: String) -> void:
	var market := _product_market_for_test(main)
	for key_variant in market.keys():
		var product_key := String(key_variant)
		var entry := (market.get(product_key, {}) as Dictionary).duplicate(true)
		entry["price"] = 54
		entry["base_price"] = 54
		entry["demand"] = 0
		entry["supply"] = 5
		entry["temporary_demand_pressure"] = 0
		entry["temporary_supply_pressure"] = 0
		entry["contract_demand_pressure"] = 0
		entry["contract_supply_pressure"] = 0
		market[product_key] = entry
	var focus_entry := (market.get(focus_product, {}) as Dictionary).duplicate(true)
	focus_entry["price"] = 260
	focus_entry["base_price"] = 120
	focus_entry["demand"] = 10
	focus_entry["supply"] = 1
	focus_entry["temporary_demand_pressure"] = 8
	focus_entry["temporary_supply_pressure"] = 0
	focus_entry["contract_demand_pressure"] = 4
	focus_entry["contract_supply_pressure"] = 0
	market[focus_product] = focus_entry
	_replace_product_market_for_test(main, market)


func _ai_memory_has_kind(players: Array, player_index: int, kind: String) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	var memory := player.get("ai_memory", {}) as Dictionary
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		if String(sample.get("kind", "")) == kind:
			return true
	return false


func _ai_memory_has_kind_with_metadata(players: Array, player_index: int, kind: String, field_name: String, expected_value: Variant) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	var memory := player.get("ai_memory", {}) as Dictionary
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		if String(sample.get("kind", "")) != kind or not sample.has(field_name):
			continue
		if sample[field_name] == expected_value:
			return true
	return false


func _find_city_guess_candidate(candidates: Array, district_index: int, guessed_player: int) -> Dictionary:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if int(candidate.get("district", -1)) == district_index and int(candidate.get("guessed_player", -1)) == guessed_player:
			return candidate
	return {}


func _find_card_guess_candidate(candidates: Array, resolution_id: int, guessed_player: int) -> Dictionary:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if int(candidate.get("resolution_id", -1)) == resolution_id and int(candidate.get("guessed_player", -1)) == guessed_player:
			return candidate
	return {}


func _find_ai_play_candidate_by_card(candidates: Array, card_name: String) -> Dictionary:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if String(candidate.get("card_name", "")) == card_name:
			return candidate
	return {}


func _graph_distance_limited(districts: Array, origin: int, target: int, max_steps: int) -> int:
	if origin < 0 or origin >= districts.size() or target < 0 or target >= districts.size() or max_steps < 0:
		return -1
	if origin == target:
		return 0
	var frontier := [{"index": origin, "distance": 0}]
	var seen := {origin: true}
	var cursor := 0
	while cursor < frontier.size():
		var item := frontier[cursor] as Dictionary
		cursor += 1
		var current := int(item.get("index", -1))
		var distance := int(item.get("distance", 0))
		if distance >= max_steps:
			continue
		for neighbor_variant in _as_array((districts[current] as Dictionary).get("neighbors", [])):
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size() or seen.has(neighbor):
				continue
			var next_distance := distance + 1
			if neighbor == target:
				return next_distance
			seen[neighbor] = true
			frontier.append({"index": neighbor, "distance": next_distance})
	return -1


func _verify_role_passive_runtime(main: Node) -> bool:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if players.is_empty() or districts.is_empty():
		return false
	var district_index := -1
	for i in range(districts.size()):
		if not _as_array((districts[i] as Dictionary).get("card_choices", [])).is_empty():
			district_index = i
			break
	if district_index < 0:
		return false
	var saved_player := (players[0] as Dictionary).duplicate(true)
	var saved_district := (districts[district_index] as Dictionary).duplicate(true)
	var saved_logs := _public_log_messages(main).duplicate(true)
	var saved_callouts := _visual_cue_array(main, "action_callouts").duplicate(true)
	var test_player := saved_player.duplicate(true)
	test_player["cash"] = 1000
	test_player["cash_history"] = [1000]
	test_player["economic_ledger"] = []
	test_player["slots"] = []
	test_player["total_card_income"] = 0
	test_player["total_city_income"] = 0
	test_player["total_role_income"] = 0
	test_player["last_cycle_income"] = 0
	test_player["role_card"] = main.call("_make_player_role_card", 0, 0)
	players[0] = test_player
	var test_district := saved_district.duplicate(true)
	var test_products := _as_array(test_district.get("products", [])).duplicate()
	for product_name in ["环晶电池", "深海菌毯"]:
		if not test_products.has(product_name):
			test_products.append(product_name)
	test_district["products"] = test_products
	districts[district_index] = test_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var hand_before := int(main.call("_player_counted_hand_size", players[0] as Dictionary))
	var bonus_card_granted := bool(main.call("_grant_role_bonus_card_on_purchase", 0, district_index, ""))
	var hand_after := int(main.call("_player_counted_hand_size", players[0] as Dictionary))
	var upgrade_player := players[0] as Dictionary
	upgrade_player["role_card"] = main.call("_make_player_role_card", 0, 3)
	players[0] = upgrade_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var cash_before_upgrade := int((players[0] as Dictionary).get("cash", 0))
	var upgrade_reward := int(main.call("_apply_role_monster_upgrade_cash", 0, "测试怪兽", 1, 2, Vector2.ZERO))
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var cash_after_upgrade := int((players[0] as Dictionary).get("cash", 0))
	var total_role_income := int((players[0] as Dictionary).get("total_role_income", 0))
	var passed := bonus_card_granted and hand_after == hand_before + 1
	passed = passed and upgrade_reward == 160 and cash_after_upgrade == cash_before_upgrade + 160
	passed = passed and total_role_income == 160
	players[0] = saved_player
	districts[district_index] = saved_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_replace_public_log_messages(main, saved_logs)
	_set_visual_cue_array(main, "action_callouts", saved_callouts)
	return passed


func _verify_role_intel_and_trace_tools(main: Node) -> bool:
	var saved_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var saved_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var saved_history := _as_array(main.get("resolved_card_history")).duplicate(true)
	var ok := true
	var city_index := _first_empty_land_district_for_contract(main)
	var contract_target_index := _first_empty_land_district_for_contract(main, [city_index])
	if city_index < 0 or contract_target_index < 0:
		ok = false
	else:
		ok = ok and _set_player_role_for_test(main, 0, "星图审计庭")
		ok = ok and CITY_FIXTURES.create_city_bool(main, 1, city_index, "情报测试城市")
		ok = ok and CITY_FIXTURES.create_city_bool(main, 2, contract_target_index, "密约测试城市")
		ok = ok and bool(main.call("_use_role_city_reveal_for_player", 0, city_index, "烟测身份侦测"))
		var players_after_role := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var role_after := (players_after_role[0] as Dictionary).get("role_card", {}) as Dictionary
		var guesses := (players_after_role[0] as Dictionary).get("city_guesses", {}) as Dictionary
		ok = ok and int(role_after.get("intel_city_reveal_charges", -1)) == 1
		ok = ok and int(guesses.get(city_index, -1)) == 1
		var history := _as_array(main.get("resolved_card_history")).duplicate(true)
		var card_resolution_id := 81001
		history.append({
			"resolution_id": card_resolution_id,
			"queued_order": card_resolution_id,
			"player_index": 1,
			"skill": main.call("_make_skill", "城市融资1"),
			"selected_district": city_index,
			"play_requirement_product": "活体芯片",
			"play_requirement_flow": 1,
			"public_owner_revealed": false,
			"guessers": [],
			"resolved_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
		})
		var contract_resolution_id := 81002
		history.append({
			"resolution_id": contract_resolution_id,
			"queued_order": contract_resolution_id,
			"player_index": 2,
			"skill": main.call("_make_skill", "区域供需合约1"),
			"selected_district": city_index,
			"contract_source_district": city_index,
			"contract_target_district": contract_target_index,
			"contract_target_owner": 1,
			"contract_response": "accepted",
			"public_owner_revealed": false,
			"guessers": [],
			"resolved_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
		})
		main.set("resolved_card_history", history)
		ok = ok and int(main.call("_trace_card_owner_for_player", 0, card_resolution_id, 1, "烟测追帧")) == 1
		ok = ok and int(_contract_controller(main).call("trace_contract_parties", 0, contract_resolution_id, 1, "烟测密约")) == 1
		var players_after_trace := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var known_cards := (players_after_trace[0] as Dictionary).get("known_card_owners", {}) as Dictionary
		var known_contracts := (players_after_trace[0] as Dictionary).get("known_contract_parties", {}) as Dictionary
		var known_contract := known_contracts.get(str(contract_resolution_id), {}) as Dictionary
		ok = ok and int(known_cards.get(str(card_resolution_id), -1)) == 1
		ok = ok and int(known_contract.get("proposer", -1)) == 2
		ok = ok and int(known_contract.get("target_owner", -1)) == 1
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = saved_players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = saved_districts
	main.set("resolved_card_history", saved_history)
	return ok


func _verify_ai_intel_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	if _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size() < 3:
		ok = false
	else:
		main.set("ai_card_decision_enabled", true)
		var source_index := _first_empty_land_district_for_contract(main)
		var target_index := _first_empty_land_district_for_contract(main, [source_index])
		if source_index < 0 or target_index < 0:
			ok = false
		else:
			var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
			for player_index in range(players.size()):
				var player := players[player_index] as Dictionary
				player["cash"] = 5000
				players[player_index] = player
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
			ok = ok and CITY_FIXTURES.create_city_bool(main, 2, source_index, "AI线索源城")
			ok = ok and CITY_FIXTURES.create_city_bool(main, 2, target_index, "AI推理目标城")
			ok = ok and _set_city_goods_for_test(main, source_index, "活体芯片", "轨迹墨水")
			ok = ok and _set_city_goods_for_test(main, target_index, "活体芯片", "轨迹墨水")
			ok = ok and bool(main.call("_mark_city_guess_for_player", 1, source_index, 2, 3, "product"))
			var city_candidates := _ai_controller(main).call("_ai_city_guess_candidates", 1) as Array
			var city_choice := _find_city_guess_candidate(city_candidates, target_index, 2)
			ok = ok and not city_choice.is_empty()
			ok = ok and int(city_choice.get("score", 0)) >= 78
			ok = ok and bool(_ai_controller(main).call("_ai_apply_city_guess_candidate", 1, city_choice, city_candidates))
			var players_after_city := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
			var city_guesses := (players_after_city[1] as Dictionary).get("city_guesses", {}) as Dictionary
			ok = ok and int(city_guesses.get(target_index, -1)) == 2
			ok = ok and _ai_memory_has_kind(players_after_city, 1, "城市业主推理")
			var resolution_id := 82001
			var history := _as_array(main.get("resolved_card_history")).duplicate(true)
			history.append({
				"resolution_id": resolution_id,
				"queued_order": resolution_id,
				"player_index": 2,
				"skill": main.call("_make_skill", "出牌追帧1"),
				"selected_district": target_index,
				"play_requirement_product": "活体芯片",
				"play_requirement_flow": 1,
				"winning_bid": 120,
				"public_owner_revealed": false,
				"guessers": [],
				"resolved_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
			})
			main.set("resolved_card_history", history)
			var card_candidates := _ai_controller(main).call("_ai_card_guess_candidates", 1) as Array
			var card_choice := _find_card_guess_candidate(card_candidates, resolution_id, 2)
			ok = ok and not card_choice.is_empty()
			ok = ok and int(card_choice.get("score", 0)) >= 125
			ok = ok and bool(_ai_controller(main).call("_ai_apply_card_guess_candidate", 1, card_choice, card_candidates))
			var traced_entry := main.call("_card_resolution_entry_by_id", resolution_id) as Dictionary
			var players_after_card := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
			ok = ok and bool(traced_entry.get("public_owner_revealed", false))
			ok = ok and _as_array(traced_entry.get("guessers", [])).has(1)
			ok = ok and _ai_memory_has_kind(players_after_card, 1, "卡牌归属押注")
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _verify_ai_monster_lure_strategy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	var failures := []
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_simultaneous_timer", 0.5)
	main.set("card_resolution_auction_open", false)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	var spare_index := _first_empty_land_district_for_contract(main, [own_index, rival_index])
	if own_index < 0 or rival_index < 0:
		ok = false
		failures.append("missing setup districts own=%d rival=%d" % [own_index, rival_index])
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 5000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "诱导电波1")]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		ok = ok and CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI诱导自城")
		ok = ok and CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI诱导竞品城")
		ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水")
		ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "轨迹墨水")
		if spare_index >= 0:
			ok = ok and CITY_FIXTURES.create_city_bool(main, 3, spare_index, "AI诱导干扰城")
			ok = ok and _set_city_goods_for_test(main, spare_index, "深海菌毯", "离岸水晶")
		var matching_actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 2, 2) as Dictionary
		matching_actor["resource_focus"] = ["环晶电池"]
		var decoy_actor := _monster_controller(main).call("_make_auto_monster", 1, 1, spare_index if spare_index >= 0 else own_index, 3, 1) as Dictionary
		decoy_actor["resource_focus"] = ["深海菌毯"]
		main.set("auto_monsters", [matching_actor, decoy_actor])
		var lure_skill := main.call("_make_skill", "诱导电波1") as Dictionary
		var context := _ai_controller(main).call("_ai_card_play_context", 1, 0, lure_skill) as Dictionary
		if context.is_empty():
			failures.append("empty context")
		if int(context.get("target_slot", -1)) != 0:
			failures.append("target_slot=%d" % int(context.get("target_slot", -1)))
		if int(context.get("district", -1)) != rival_index:
			failures.append("district=%d expected=%d" % [int(context.get("district", -1)), rival_index])
		if int(context.get("target_city", -1)) != rival_index:
			failures.append("target_city=%d expected=%d" % [int(context.get("target_city", -1)), rival_index])
		if String(context.get("strategic_role", "")) != "monster_lure":
			failures.append("role=%s" % String(context.get("strategic_role", "")))
		if int(context.get("resource_match", 0)) <= 0:
			failures.append("resource_match=%d" % int(context.get("resource_match", 0)))
		if int(context.get("product_overlap", 0)) <= 0:
			failures.append("product_overlap=%d" % int(context.get("product_overlap", 0)))
		if int(context.get("attack_value", 0)) <= 0:
			failures.append("attack_value=%d" % int(context.get("attack_value", 0)))
		ok = ok and failures.is_empty()
		var candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var chosen := {}
		for candidate_variant in candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "诱导电波1":
				chosen = candidate
				break
		if chosen.is_empty():
			failures.append("missing lure candidate count=%d" % candidates.size())
		ok = ok and not chosen.is_empty()
		var lure_queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, chosen, candidates))
		if not lure_queued:
			failures.append("queue failed chosen=%s" % str(chosen))
		ok = ok and lure_queued
		var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		if not _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "target_city", rival_index):
			failures.append("missing target_city memory expected=%d chosen=%s" % [rival_index, str(chosen)])
		if not _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "strategic_role", "monster_lure"):
			failures.append("missing strategic_role memory")
		ok = ok and failures.is_empty()
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	if not failures.is_empty():
		print("AI monster lure failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _verify_ai_economic_focus_strategy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_simultaneous_timer", 0.5)
	main.set("card_resolution_auction_open", false)
	var own_index := _first_empty_land_district_for_contract(main)
	var focus_index := _first_empty_land_district_for_contract(main, [own_index])
	var decoy_index := _first_empty_land_district_for_contract(main, [own_index, focus_index])
	if own_index < 0 or focus_index < 0 or decoy_index < 0:
		ok = false
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 5000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "价格套利1")]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		ok = ok and CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI焦点电池城")
		ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水")
		ok = ok and _set_district_goods_for_test(main, focus_index, "环晶电池", "离岸水晶")
		ok = ok and _set_district_goods_for_test(main, decoy_index, "深海菌毯", "星尘香料")
		var market := _product_market_for_test(main)
		var focus_entry := (market.get("环晶电池", {}) as Dictionary).duplicate(true)
		focus_entry["price"] = 240
		focus_entry["base_price"] = 120
		focus_entry["demand"] = 8
		focus_entry["supply"] = 1
		market["环晶电池"] = focus_entry
		var decoy_entry := (market.get("深海菌毯", {}) as Dictionary).duplicate(true)
		decoy_entry["price"] = 70
		decoy_entry["base_price"] = 70
		decoy_entry["demand"] = 1
		decoy_entry["supply"] = 4
		market["深海菌毯"] = decoy_entry
		_replace_product_market_for_test(main, market)
		var focus_product := String(_ai_controller(main).call("_ai_refresh_economic_focus", 1, true))
		ok = ok and focus_product == "环晶电池"
		var players_after_focus := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var memory := (players_after_focus[1] as Dictionary).get("ai_memory", {}) as Dictionary
		ok = ok and String(memory.get("economic_focus_product", "")) == "环晶电池"
		ok = ok and String(memory.get("economic_focus_reason", "")).contains("通关缺口")
		var focus_build_score := int(_ai_controller(main).call("_auto_build_score_for_player", 1, focus_index))
		var decoy_build_score := int(_ai_controller(main).call("_auto_build_score_for_player", 1, decoy_index))
		ok = ok and focus_build_score > decoy_build_score
		var skill := main.call("_make_skill", "价格套利1") as Dictionary
		var context := _ai_controller(main).call("_ai_card_play_context", 1, 0, skill) as Dictionary
		ok = ok and not context.is_empty()
		ok = ok and String(context.get("product", "")) == "环晶电池"
		ok = ok and String(context.get("focus_product", "")) == "环晶电池"
		ok = ok and int(context.get("focus_bonus", 0)) > 0
		var candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var chosen := {}
		for candidate_variant in candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "价格套利1":
				chosen = candidate
				break
		ok = ok and not chosen.is_empty()
		ok = ok and bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, chosen, candidates))
		var players_after_queue := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		ok = ok and _ai_memory_has_kind_with_metadata(players_after_queue, 1, "匿名出牌", "focus_product", "环晶电池")
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _verify_ai_strategy_intent_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.call("_new_game")
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	var strategy_base := main.call("_capture_run_state") as Dictionary

	var own_index := _first_empty_land_district_for_contract(main)
	if own_index < 0:
		ok = false
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 900
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "价格套利1")]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var grow_created := CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI策略成长城")
		var grow_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水") if grow_created else false
		var grow_strategy := _ai_controller(main).call("_ai_refresh_strategy_intent", 1, true) as Dictionary
		var grow_ok := grow_created and grow_goods and String(grow_strategy.get("intent", "")) == "grow_focus"
		if not grow_ok:
			print("AI strategy grow failures: created=%s goods=%s intent=%s strategy=%s" % [
				str(grow_created),
				str(grow_goods),
				String(grow_strategy.get("intent", "")),
				str(grow_strategy),
			])
		ok = grow_ok and ok

	var restore_mid := int(main.call("_apply_run_state", strategy_base))
	ok = ok and restore_mid == OK
	main.set("ai_card_decision_enabled", true)
	own_index = _first_empty_land_district_for_contract(main)
	if own_index < 0:
		ok = false
	else:
		var defend_fixture_cash_scale := 10000
		var defend_leader_cash := maxi(5000, int(round(float(defend_fixture_cash_scale) * 0.84)))
		var defend_other_cash := maxi(1800, int(round(float(defend_fixture_cash_scale) * 0.38)))
		var defend_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(defend_players.size()):
			var player := defend_players[player_index] as Dictionary
			player["cash"] = defend_leader_cash if player_index == 1 else defend_other_cash
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "供应链保险1")]
			defend_players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = defend_players
		var defend_created := CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI策略防守城")
		var defend_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水") if defend_created else false
		var defend_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var defend_district := defend_districts[own_index] as Dictionary
		var defend_city := defend_district.get("city", {}) as Dictionary
		defend_city["trade_route_damage"] = 8
		defend_city["trade_disrupted_routes"] = 2
		defend_district["city"] = defend_city
		defend_district["damage"] = maxi(int(defend_district.get("damage", 0)), 4)
		defend_districts[own_index] = defend_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = defend_districts
		main.set("business_cycle_count", 3)
		var defend_actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 1, 1) as Dictionary
		main.set("auto_monsters", [defend_actor])
		var defend_phase_info := _ai_controller(main).call("_ai_refresh_game_phase", 1, true) as Dictionary
		var defend_rankings := _ai_controller(main).call("_ai_strategy_candidates", 1) as Array
		var defend_strategy := _ai_controller(main).call("_ai_refresh_strategy_intent", 1, true) as Dictionary
		var defend_skill := main.call("_make_skill", "供应链保险1") as Dictionary
		var defend_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, defend_skill) as Dictionary
		var defend_candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var defend_choice := {}
		for candidate_variant in defend_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "供应链保险1":
				defend_choice = candidate
				break
		var defend_queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, defend_choice, defend_candidates)) if not defend_choice.is_empty() else false
		var players_after_defend := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var defend_memory := _ai_memory_has_kind_with_metadata(players_after_defend, 1, "匿名出牌", "strategy_intent", "defend_routes")
		var defend_ok := (
			defend_created
			and defend_goods
			and String(defend_strategy.get("intent", "")) == "defend_routes"
			and not defend_context.is_empty()
			and String(defend_context.get("strategy_intent", "")) == "defend_routes"
			and int(defend_context.get("strategy_bonus", 0)) > 0
			and not defend_choice.is_empty()
			and defend_queued
			and defend_memory
		)
		if not defend_ok:
			print("AI strategy defend failures: created=%s goods=%s phase=%s posture=%s intent=%s context=%s context_intent=%s bonus=%d choice=%s queued=%s memory=%s candidates=%d rankings=%s" % [
				str(defend_created),
				str(defend_goods),
				String(defend_phase_info.get("phase", "")),
				String(defend_phase_info.get("posture", "")),
				String(defend_strategy.get("intent", "")),
				str(not defend_context.is_empty()),
				String(defend_context.get("strategy_intent", "")),
				int(defend_context.get("strategy_bonus", 0)),
				str(not defend_choice.is_empty()),
				str(defend_queued),
				str(defend_memory),
				defend_candidates.size(),
				str(defend_rankings),
			])
		ok = defend_ok and ok

	restore_mid = int(main.call("_apply_run_state", strategy_base))
	ok = ok and restore_mid == OK
	main.set("ai_card_decision_enabled", true)
	own_index = _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var disrupt_fixture_cash_scale := 10000
		var disrupt_ai_cash := maxi(2600, int(round(float(disrupt_fixture_cash_scale) * 0.36)))
		var disrupt_rival_cash := maxi(5200, int(round(float(disrupt_fixture_cash_scale) * 0.82)))
		var disrupt_neutral_cash := maxi(2400, int(round(float(disrupt_fixture_cash_scale) * 0.42)))
		var disrupt_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(disrupt_players.size()):
			var player := disrupt_players[player_index] as Dictionary
			player["cash"] = disrupt_ai_cash if player_index == 1 else (disrupt_rival_cash if player_index == 2 else disrupt_neutral_cash)
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "商路黑客1")]
			disrupt_players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = disrupt_players
		var disrupt_own_created := CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI策略竞品自城")
		var disrupt_rival_created := CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI策略竞品敌城")
		var disrupt_own_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池") if disrupt_own_created else false
		var disrupt_rival_goods := _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料") if disrupt_rival_created else false
		var disrupt_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var rival_district := disrupt_districts[rival_index] as Dictionary
		var rival_city := rival_district.get("city", {}) as Dictionary
		rival_city["last_income"] = 820
		rival_district["city"] = rival_city
		disrupt_districts[rival_index] = rival_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = disrupt_districts
		main.set("business_cycle_count", 3)
		var disrupt_actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 1, 1) as Dictionary
		main.set("auto_monsters", [disrupt_actor])
		var disrupt_strategy := _ai_controller(main).call("_ai_refresh_strategy_intent", 1, true) as Dictionary
		var business_candidates := _ai_controller(main).call("_rival_business_candidates_for_player", 1) as Array
		var saw_disrupt_bonus := false
		for candidate_variant in business_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("kind", "")) == "route_sabotage" and int(candidate.get("target_city", -1)) == rival_index and String(candidate.get("strategy_intent", "")) == "disrupt_competitors" and int(candidate.get("strategy_bonus", 0)) > 0:
				saw_disrupt_bonus = true
				break
		var disrupt_skill := main.call("_make_skill", "商路黑客1") as Dictionary
		var disrupt_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, disrupt_skill) as Dictionary
		var disrupt_play_candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var disrupt_choice := {}
		for candidate_variant in disrupt_play_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "商路黑客1":
				disrupt_choice = candidate
				break
		var disrupt_queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, disrupt_choice, disrupt_play_candidates)) if not disrupt_choice.is_empty() else false
		var players_after_disrupt := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var disrupt_memory := _ai_memory_has_kind_with_metadata(players_after_disrupt, 1, "匿名出牌", "strategy_intent", "disrupt_competitors")
		var disrupt_ok := (
			disrupt_own_created
			and disrupt_rival_created
			and disrupt_own_goods
			and disrupt_rival_goods
			and String(disrupt_strategy.get("intent", "")) == "disrupt_competitors"
			and saw_disrupt_bonus
			and not disrupt_context.is_empty()
			and String(disrupt_context.get("strategy_intent", "")) == "disrupt_competitors"
			and int(disrupt_context.get("strategy_bonus", 0)) > 0
			and not disrupt_choice.is_empty()
			and int(disrupt_choice.get("target_city", -1)) == rival_index
			and disrupt_queued
			and disrupt_memory
		)
		if not disrupt_ok:
			print("AI strategy disrupt failures: own=%s rival=%s own_goods=%s rival_goods=%s intent=%s business=%s context=%s context_intent=%s bonus=%d choice=%s target=%d expected=%d queued=%s memory=%s candidates=%d" % [
				str(disrupt_own_created),
				str(disrupt_rival_created),
				str(disrupt_own_goods),
				str(disrupt_rival_goods),
				String(disrupt_strategy.get("intent", "")),
				str(saw_disrupt_bonus),
				str(not disrupt_context.is_empty()),
				String(disrupt_context.get("strategy_intent", "")),
				int(disrupt_context.get("strategy_bonus", 0)),
				str(not disrupt_choice.is_empty()),
				int(disrupt_choice.get("target_city", -1)),
				rival_index,
				str(disrupt_queued),
				str(disrupt_memory),
				disrupt_play_candidates.size(),
			])
		ok = disrupt_ok and ok
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _verify_ai_route_plan_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	_reset_route_plan_sandbox_for_test(main)
	ok = ok and _reset_ai_memory_for_test(main, 1)
	ok = ok and _set_player_role_for_test(main, 1, "环港走私议会")
	_set_product_market_focus_for_test(main, "环晶电池")

	var seed_index := _first_empty_land_district_for_contract(main)
	var decoy_index := _first_empty_land_district_for_contract(main, [seed_index])
	if seed_index < 0 or decoy_index < 0:
		ok = false
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 5200
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "需求改造1")]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var seed_goods_set := _set_district_goods_for_test(main, seed_index, "环晶电池", "轨迹墨水")
		var decoy_goods_set := _set_district_goods_for_test(main, decoy_index, "深海菌毯", "星尘香料")
		var build_plan := _ai_controller(main).call("_ai_refresh_route_plan", 1, true) as Dictionary
		var seed_build_score := int(_ai_controller(main).call("_auto_build_score_for_player", 1, seed_index))
		var decoy_build_score := int(_ai_controller(main).call("_auto_build_score_for_player", 1, decoy_index))
		var build_ok := seed_goods_set and decoy_goods_set and String(build_plan.get("product", "")) == "环晶电池" and String(build_plan.get("stage", "")) == "build_supply" and int(build_plan.get("partner_district", -1)) == seed_index and seed_build_score > decoy_build_score
		var route_city_created := CITY_FIXTURES.create_city_bool(main, 1, seed_index, "AI路线供给城")
		var route_goods_set := _set_city_goods_for_test(main, seed_index, "环晶电池", "轨迹墨水") if route_city_created else false
		var demand_plan := _ai_controller(main).call("_ai_refresh_route_plan", 1, true) as Dictionary
		var demand_plan_ok := route_city_created and route_goods_set and String(demand_plan.get("product", "")) == "环晶电池" and String(demand_plan.get("stage", "")) == "create_demand"
		var demand_skill := main.call("_make_skill", "需求改造1") as Dictionary
		var demand_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, demand_skill) as Dictionary
		var demand_context_ok := not demand_context.is_empty() and String(demand_context.get("route_plan_product", "")) == "环晶电池" and String(demand_context.get("route_plan_stage", "")) == "create_demand" and int(demand_context.get("route_plan_bonus", 0)) > 0
		var districts_for_supply := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var supply_district := districts_for_supply[seed_index] as Dictionary
		supply_district["card_choices"] = ["需求改造1"]
		districts_for_supply[seed_index] = supply_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts_for_supply
		var actor := _monster_controller(main).call("_make_auto_monster", 0, 0, seed_index, 1, 1) as Dictionary
		main.set("auto_monsters", [actor])
		var buy_candidates := _ai_controller(main).call("_ai_card_buy_candidates", 1) as Array
		var saw_route_buy := false
		for candidate_variant in buy_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "需求改造1" and String(candidate.get("route_plan_stage", "")) == "create_demand" and int(candidate.get("route_plan_bonus", 0)) > 0:
				saw_route_buy = true
				break
		var demand_gap := _ai_controller(main).call("_ai_route_gap_adjustment", 1, main.call("_make_skill", "消费刺激1"), seed_index, "环晶电池", 1) as Dictionary
		var supply_gap := _ai_controller(main).call("_ai_route_gap_adjustment", 1, main.call("_make_skill", "生产扩张1"), seed_index, "环晶电池", 1) as Dictionary
		var route_gap_direct_ok := int(demand_gap.get("bonus", 0)) > int(supply_gap.get("bonus", 0)) and String(demand_gap.get("reason", "")).contains("补需求")
		var districts_for_gap := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var gap_district := districts_for_gap[seed_index] as Dictionary
		gap_district["card_choices"] = ["消费刺激1", "生产扩张1"]
		districts_for_gap[seed_index] = gap_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts_for_gap
		var gap_candidates := _ai_controller(main).call("_ai_card_buy_candidates", 1) as Array
		var saw_route_gap_buy := false
		var demand_gap_score := -999999
		var supply_gap_score := -999999
		for candidate_variant in gap_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "消费刺激1":
				demand_gap_score = maxi(demand_gap_score, int(candidate.get("score", 0)))
				saw_route_gap_buy = int(candidate.get("route_gap_bonus", 0)) > int(candidate.get("route_gap_penalty", 0)) and String(candidate.get("route_gap_reason", "")).contains("补需求") and int(candidate.get("route_gap_field_match", 0)) >= 2
			elif String(candidate.get("card_name", "")) == "生产扩张1":
				supply_gap_score = maxi(supply_gap_score, int(candidate.get("score", 0)))
		var contract_skill := main.call("_make_skill", "环晶电池专供1") as Dictionary
		var contract_entry := {
			"skill": contract_skill,
			"contract_source_district": seed_index,
			"contract_target_district": seed_index,
			"contract_products": ["环晶电池"],
		}
		var contract_candidates := _ai_controller(main).call("_ai_contract_response_candidates", 1, contract_entry) as Array
		var saw_route_contract := false
		var saw_contract_metadata := false
		for candidate_variant in contract_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("action", "")) == "签约" and String(candidate.get("route_plan_stage", "")) == "create_demand" and int(candidate.get("route_plan_bonus", 0)) > 0:
				saw_route_contract = true
				saw_contract_metadata = String(candidate.get("contract_response_role", "")) == "accept_route_plan" \
					and int(candidate.get("contract_route_match", 0)) == 1 \
					and int(candidate.get("contract_accept_value", 0)) > int(candidate.get("contract_reject_value", 0)) \
					and int(candidate.get("contract_response_margin", 0)) > 0 \
					and candidate.has("contract_decline_risk") \
					and candidate.has("contract_accept_economic_delta")
				break
		var play_candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var play_choice := {}
		for candidate_variant in play_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "需求改造1":
				play_choice = candidate
				break
		var saw_route_gap_play := not play_choice.is_empty() and int(play_choice.get("route_gap_bonus", 0)) > int(play_choice.get("route_gap_penalty", 0)) and String(play_choice.get("route_gap_reason", "")).contains("补需求")
		var route_play_queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, play_choice, play_candidates)) if not play_choice.is_empty() else false
		var players_after_queue := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var route_play_memory := _ai_memory_has_kind_with_metadata(players_after_queue, 1, "匿名出牌", "route_plan_stage", "create_demand")
		var route_gap_score_ok := demand_gap_score > supply_gap_score
		var first_route_ok := build_ok and demand_plan_ok and demand_context_ok and saw_route_buy and route_gap_direct_ok and saw_route_gap_buy and route_gap_score_ok and saw_route_gap_play and saw_route_contract and saw_contract_metadata and not play_choice.is_empty() and route_play_queued and route_play_memory
		if not first_route_ok:
			print("AI route plan first-route failures: build=%s demand_plan=%s demand_context=%s route_buy=%s gap_direct=%s gap_buy=%s gap_score=%s gap_play=%s contract=%s contract_meta=%s play_choice=%s queued=%s memory=%s demand_score=%d supply_score=%d" % [
				str(build_ok),
				str(demand_plan_ok),
				str(demand_context_ok),
				str(saw_route_buy),
				str(route_gap_direct_ok),
				str(saw_route_gap_buy),
				str(route_gap_score_ok),
				str(saw_route_gap_play),
				str(saw_route_contract),
				str(saw_contract_metadata),
				str(not play_choice.is_empty()),
				str(route_play_queued),
				str(route_play_memory),
				demand_gap_score,
				supply_gap_score,
			])
		ok = first_route_ok and ok
		var inventory_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		var inventory_player := inventory_players[1] as Dictionary
		var blocked_growth_a := main.call("_make_skill", "城市融资1") as Dictionary
		blocked_growth_a["play_requirement_kind"] = "region_gdp_share"
		blocked_growth_a["play_region_scope"] = "target_region"
		blocked_growth_a["play_region_gdp_share_required"] = 40
		blocked_growth_a["play_requirement_district"] = decoy_index
		var blocked_growth_b := main.call("_make_skill", "需求改造1") as Dictionary
		blocked_growth_b["play_requirement_kind"] = "region_gdp_share"
		blocked_growth_b["play_region_scope"] = "target_region"
		blocked_growth_b["play_region_gdp_share_required"] = 40
		blocked_growth_b["play_requirement_district"] = decoy_index
		inventory_player["slots"] = [blocked_growth_a, blocked_growth_b]
		inventory_player["cash"] = 5200
		inventory_player["action_cooldown"] = 0.0
		inventory_players[1] = inventory_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = inventory_players
		var growth_inventory := _ai_controller(main).call("_ai_route_hand_inventory", 1, "city_growth") as Dictionary
		var growth_adjustment := _ai_controller(main).call("_ai_route_inventory_adjustment", 1, "city_growth", 0, 0, 2, 1, 1) as Dictionary
		var saw_inventory_bonus := int(growth_inventory.get("total", 0)) >= 2 \
			and int(growth_inventory.get("blocked_region_share", 0)) >= 2 \
			and int(growth_adjustment.get("bonus", 0)) > 0 \
			and int(growth_adjustment.get("penalty", 0)) == 0
		var blocked_intel_a := main.call("_make_skill", "业主透镜1") as Dictionary
		blocked_intel_a["play_requirement_kind"] = "region_gdp_share"
		blocked_intel_a["play_region_scope"] = "target_region"
		blocked_intel_a["play_region_gdp_share_required"] = 40
		blocked_intel_a["play_requirement_district"] = decoy_index
		var blocked_intel_b := main.call("_make_skill", "密约回溯1") as Dictionary
		blocked_intel_b["play_requirement_kind"] = "region_gdp_share"
		blocked_intel_b["play_region_scope"] = "target_region"
		blocked_intel_b["play_region_gdp_share_required"] = 40
		blocked_intel_b["play_requirement_district"] = decoy_index
		inventory_players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		inventory_player = inventory_players[1] as Dictionary
		inventory_player["slots"] = [blocked_intel_a, blocked_intel_b]
		inventory_players[1] = inventory_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = inventory_players
		var intel_inventory := _ai_controller(main).call("_ai_route_hand_inventory", 1, "intel_supply") as Dictionary
		var intel_adjustment := _ai_controller(main).call("_ai_route_inventory_adjustment", 1, "intel_supply", 4, 0, 2, 0, 0) as Dictionary
		var saw_inventory_penalty := int(intel_inventory.get("total", 0)) >= 2 \
			and int(intel_inventory.get("blocked_region_share", 0)) >= 2 \
			and int(intel_adjustment.get("penalty", 0)) > 0
		ok = ok and saw_inventory_bonus and saw_inventory_penalty

	var restore_mid := int(main.call("_apply_run_state", saved))
	ok = ok and restore_mid == OK
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	_reset_route_plan_sandbox_for_test(main)
	ok = ok and _reset_ai_memory_for_test(main, 1)
	ok = ok and _set_player_role_for_test(main, 1, "环港走私议会")
	_set_product_market_focus_for_test(main, "环晶电池")
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var rival_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(rival_players.size()):
			var player := rival_players[player_index] as Dictionary
			player["cash"] = 5200
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "商路黑客1")]
			rival_players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = rival_players
		var attack_own_created := CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI路线自城")
		var attack_rival_created := CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI路线竞品城")
		var attack_own_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池") if attack_own_created else false
		var attack_rival_goods := _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料") if attack_rival_created else false
		var districts_for_rival := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var rival_district := districts_for_rival[rival_index] as Dictionary
		var rival_city := rival_district.get("city", {}) as Dictionary
		rival_city["last_income"] = 920
		rival_district["city"] = rival_city
		districts_for_rival[rival_index] = rival_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts_for_rival
		var attack_plan := _ai_controller(main).call("_ai_refresh_route_plan", 1, true) as Dictionary
		var business_candidates := _ai_controller(main).call("_rival_business_candidates_for_player", 1) as Array
		var saw_attack_business := false
		for candidate_variant in business_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("kind", "")) == "route_sabotage" and int(candidate.get("target_city", -1)) == rival_index and String(candidate.get("route_plan_stage", "")) == "attack_rival" and int(candidate.get("route_plan_bonus", 0)) > 0:
				saw_attack_business = true
				break
		var attack_skill := main.call("_make_skill", "商路黑客1") as Dictionary
		var attack_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, attack_skill) as Dictionary
		var attack_play_candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var attack_choice := {}
		for candidate_variant in attack_play_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "商路黑客1":
				attack_choice = candidate
				break
		var attack_queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, attack_choice, attack_play_candidates)) if not attack_choice.is_empty() else false
		var players_after_attack_queue := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var attack_play_memory := _ai_memory_has_kind_with_metadata(players_after_attack_queue, 1, "匿名出牌", "route_plan_stage", "attack_rival")
		var attack_ok := (
			attack_own_created
			and attack_rival_created
			and attack_own_goods
			and attack_rival_goods
			and String(attack_plan.get("product", "")) == "环晶电池"
			and String(attack_plan.get("stage", "")) == "attack_rival"
			and saw_attack_business
			and not attack_context.is_empty()
			and String(attack_context.get("route_plan_stage", "")) == "attack_rival"
			and int(attack_context.get("route_plan_bonus", 0)) > 0
			and not attack_choice.is_empty()
			and int(attack_choice.get("target_city", -1)) == rival_index
			and attack_queued
			and attack_play_memory
		)
		if not attack_ok:
			print("AI route plan attack-route failures: own=%s rival=%s own_goods=%s rival_goods=%s plan=%s/%s business=%s context=%s context_stage=%s context_bonus=%d choice=%s choice_target=%d expected=%d queued=%s memory=%s" % [
				str(attack_own_created),
				str(attack_rival_created),
				str(attack_own_goods),
				str(attack_rival_goods),
				String(attack_plan.get("product", "")),
				String(attack_plan.get("stage", "")),
				str(saw_attack_business),
				str(not attack_context.is_empty()),
				String(attack_context.get("route_plan_stage", "")),
				int(attack_context.get("route_plan_bonus", 0)),
				str(not attack_choice.is_empty()),
				int(attack_choice.get("target_city", -1)),
				rival_index,
				str(attack_queued),
				str(attack_play_memory),
			])
		ok = attack_ok and ok
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _ai_sample_has_field(players: Array, player_index: int, field_name: String, expected: Variant = null) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var memory := (players[player_index] as Dictionary).get("ai_memory", {}) as Dictionary
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		if not sample.has(field_name):
			continue
		if expected == null or sample[field_name] == expected:
			return true
	return false


func _verify_ai_game_phase_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("business_cycle_count", 0)
	main.set("auto_monsters", [])
	var victory_controller := _victory_controller(main)
	if victory_controller == null:
		return false
	victory_controller.call("reset_state")
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	if players.size() < 3:
		ok = false
	else:
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 900
			player["action_cooldown"] = 0.0
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var opening := _ai_controller(main).call("_ai_refresh_game_phase", 1, true) as Dictionary
		ok = ok and String(opening.get("phase", "")) == "opening"
		var own_index := _first_empty_land_district_for_contract(main)
		var rival_index := _first_empty_land_district_for_contract(main, [own_index])
		if own_index < 0 or rival_index < 0:
			ok = false
		else:
			ok = ok and CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI阶段自城")
			ok = ok and CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI阶段敌城")
			ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池")
			ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料")
			var actor := _monster_controller(main).call("_make_auto_monster", 0, 0, own_index, 1, 1) as Dictionary
			main.set("auto_monsters", [actor])
			main.set("business_cycle_count", 3)
			var midgame := _ai_controller(main).call("_ai_refresh_game_phase", 1, true) as Dictionary
			ok = ok and String(midgame.get("phase", "")) == "midgame"
			victory_controller.call("reset_state")
			var trailing_world := _victory_three_player_world([], [20, 20, 20], [45, 40, 35], [50000, 80000, 120000])
			victory_controller.call("advance_world_effective", 0.0, trailing_world)
			main.set("business_cycle_count", 8)
			var trailing := _ai_controller(main).call("_ai_refresh_game_phase", 1, true) as Dictionary
			ok = ok and String(trailing.get("phase", "")) == "endgame"
			ok = ok and String(trailing.get("posture", "")) == "trailing"
			ok = ok and int(trailing.get("leader_index", -1)) == 2
			var saw_trailing_disrupt := false
			for candidate_variant in _ai_controller(main).call("_ai_strategy_candidates", 1) as Array:
				if not (candidate_variant is Dictionary):
					continue
				var candidate := candidate_variant as Dictionary
				if String(candidate.get("intent", "")) == "disrupt_competitors" \
					and String(candidate.get("game_phase", "")) == "endgame" \
					and String(candidate.get("competitive_posture", "")) == "trailing" \
					and int(candidate.get("phase_bonus", 0)) > 0:
					saw_trailing_disrupt = true
					break
			var sabotage_bonus := int(_ai_controller(main).call("_ai_phase_bonus_for_candidate", 1, "route_sabotage", rival_index, "环晶电池", 2, {}))
			ok = ok and saw_trailing_disrupt and sabotage_bonus > 0
			victory_controller.call("advance_world_effective", 10.0, trailing_world)
			var audit_urgency := int(_ai_controller(main).call("_ai_endgame_urgency_score", 1))
			var urgent_sabotage_bonus := int(_ai_controller(main).call("_ai_phase_bonus_for_candidate", 1, "route_sabotage", rival_index, "环晶电池", 2, {}))
			var sabotage_skill := main.call("_make_skill", "商路黑客1") as Dictionary
			var sabotage_victory := _ai_controller(main).call("_ai_victory_race_bonus_for_candidate", 1, "route_sabotage", rival_index, "环晶电池", 2, sabotage_skill) as Dictionary
			var sabotage_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, sabotage_skill) as Dictionary
			ok = ok \
				and audit_urgency > 0 \
				and urgent_sabotage_bonus > sabotage_bonus \
				and int(sabotage_victory.get("bonus", 0)) > 0 \
				and String(sabotage_victory.get("role", "")) == "break_audit_lead" \
				and not sabotage_context.is_empty() \
				and int(sabotage_context.get("endgame_urgency", 0)) == audit_urgency \
				and int(sabotage_context.get("phase_bonus", 0)) >= urgent_sabotage_bonus \
				and int(sabotage_context.get("victory_race_bonus", 0)) >= int(sabotage_victory.get("bonus", 0)) \
				and String(sabotage_context.get("victory_race_role", "")) == "break_audit_lead"
			victory_controller.call("reset_state")
			victory_controller.call("advance_world_effective", 10.0, _victory_three_player_world([], [50, 40, 35], [20, 20, 20], [50000, 150000, 60000]))
			var leader_phase := _ai_controller(main).call("_ai_refresh_game_phase", 1, true) as Dictionary
			var defense_bonus := int(_ai_controller(main).call("_ai_phase_bonus_for_candidate", 1, "route_insurance", own_index, "环晶电池", 1, {}))
			var defense_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			var defense_district := defense_districts[own_index] as Dictionary
			defense_district["damage"] = int(defense_district.get("damage", 0)) + 2
			var defense_city := defense_district.get("city", {}) as Dictionary
			defense_city["trade_route_damage"] = int(defense_city.get("trade_route_damage", 0)) + 2
			defense_city["last_income"] = maxi(600, int(defense_city.get("last_income", 0)))
			defense_district["city"] = defense_city
			defense_districts[own_index] = defense_district
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = defense_districts
			var insurance_skill := main.call("_make_skill", "灾害保单1") as Dictionary
			insurance_skill["starter_play_free"] = true
			var insurance_phase_bonus := int(_ai_controller(main).call("_ai_phase_bonus_for_candidate", 1, "city_gdp_derivative", own_index, "环晶电池", 1, insurance_skill))
			var insurance_victory := _ai_controller(main).call("_ai_victory_race_bonus_for_candidate", 1, "city_gdp_derivative", own_index, "轨迹墨水", 1, insurance_skill) as Dictionary
			var insurance_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, insurance_skill) as Dictionary
			ok = ok and String(leader_phase.get("phase", "")) == "endgame"
			ok = ok and String(leader_phase.get("posture", "")) == "leader"
			ok = ok and defense_bonus > 0
			ok = ok \
				and insurance_phase_bonus > 0 \
				and int(insurance_victory.get("bonus", 0)) > 0 \
				and String(insurance_victory.get("role", "")) == "protect_lead" \
				and not insurance_context.is_empty() \
				and String(insurance_context.get("policy_kind", "")) == "city_gdp_derivative_insurance" \
				and int(insurance_context.get("target_city", -1)) == own_index \
				and int(insurance_context.get("target_owner", -1)) == 1 \
				and int(insurance_context.get("victory_race_bonus", 0)) >= int(insurance_victory.get("bonus", 0)) \
				and String(insurance_context.get("victory_race_role", "")) == "protect_lead" \
				and int(insurance_context.get("generic_effect_bonus", 0)) > 0
			_ai_controller(main).call("_record_ai_decision", 1, "阶段烟测", own_index, 123, "阶段策略记录", [], {"policy_kind": "phase_smoke", "phase_bonus": defense_bonus, "victory_race_bonus": int(insurance_victory.get("bonus", 0)), "victory_race_role": String(insurance_victory.get("role", ""))})
			var after_record := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
			ok = ok and _ai_sample_has_field(after_record, 1, "game_phase", "endgame")
			ok = ok and _ai_sample_has_field(after_record, 1, "competitive_posture", "leader")
			ok = ok and _ai_sample_has_field(after_record, 1, "endgame_urgency")
			ok = ok and _ai_sample_has_field(after_record, 1, "victory_race_role", "protect_lead")
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _verify_ai_weather_control_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	var failures := []
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	_reset_contract_runtime(main)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	_reset_route_plan_sandbox_for_test(main)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	var support_index := _first_empty_land_district_for_contract(main, [own_index, rival_index])
	if own_index < 0 or rival_index < 0:
		failures.append("missing land slots")
		ok = false
	else:
		ok = ok and CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI天气自城")
		ok = ok and CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI天气竞城")
		if support_index >= 0:
			ok = ok and CITY_FIXTURES.create_city_bool(main, 1, support_index, "AI天气需求城")
		ok = ok and _set_city_products_and_demands_for_test(main, own_index, ["离岸水晶", "轨迹墨水", "潮汐电浆"], ["环晶电池", "蓝潮藻"], 3)
		ok = ok and _set_city_products_and_demands_for_test(main, rival_index, ["环晶电池", "太阳鳞片"], ["离岸水晶", "轨迹墨水"], 3)
		if support_index >= 0:
			ok = ok and _set_city_products_and_demands_for_test(main, support_index, ["蓝潮藻"], ["离岸水晶"], 2)
		var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var own_district := districts[own_index] as Dictionary
		var own_city := own_district.get("city", {}) as Dictionary
		own_city["last_income"] = 860
		own_city["trade_routes"] = [
			{"product": "离岸水晶", "source": own_index, "destination": support_index if support_index >= 0 else own_index, "path": [own_index, support_index if support_index >= 0 else own_index], "disrupted": false},
			{"product": "潮汐电浆", "source": own_index, "destination": support_index if support_index >= 0 else own_index, "path": [own_index, support_index if support_index >= 0 else own_index], "disrupted": false},
		]
		own_district["transport_score"] = 1.45
		own_district["city"] = own_city
		districts[own_index] = own_district
		var rival_district := districts[rival_index] as Dictionary
		var rival_city := rival_district.get("city", {}) as Dictionary
		rival_city["last_income"] = 980
		rival_city["trade_routes"] = [
			{"product": "环晶电池", "source": rival_index, "destination": own_index, "path": [rival_index, own_index], "disrupted": false},
		]
		rival_district["transport_score"] = 1.1
		rival_district["panic"] = 30
		rival_district["city"] = rival_city
		districts[rival_index] = rival_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
		main.call("_refresh_city_networks")
		# Restore explicit route pressure after network refresh, because the test wants deterministic weather-route scoring.
		districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		own_district = districts[own_index] as Dictionary
		own_city = own_district.get("city", {}) as Dictionary
		own_city["last_income"] = 860
		own_city["trade_routes"] = [
			{"product": "离岸水晶", "source": own_index, "destination": support_index if support_index >= 0 else own_index, "path": [own_index, support_index if support_index >= 0 else own_index], "disrupted": false},
			{"product": "潮汐电浆", "source": own_index, "destination": support_index if support_index >= 0 else own_index, "path": [own_index, support_index if support_index >= 0 else own_index], "disrupted": false},
		]
		own_district["city"] = own_city
		districts[own_index] = own_district
		rival_district = districts[rival_index] as Dictionary
		rival_city = rival_district.get("city", {}) as Dictionary
		rival_city["last_income"] = 980
		rival_city["trade_routes"] = [{"product": "环晶电池", "source": rival_index, "destination": own_index, "path": [rival_index, own_index], "disrupted": false}]
		rival_district["city"] = rival_city
		districts[rival_index] = rival_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 7000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				var memory := _ai_controller(main).call("_empty_ai_memory") as Dictionary
				memory["economic_focus_product"] = "离岸水晶"
				memory["economic_focus_score"] = 900
				memory["strategy_intent"] = "defend_routes"
				memory["strategy_score"] = 850
				memory["route_plan_product"] = "离岸水晶"
				memory["route_plan_stage"] = "defend_route"
				memory["route_plan_score"] = 880
				player["ai_memory"] = memory
				player["slots"] = [{"kind": "weather_control", "weather_type": "gravity_tide"}, {"kind": "weather_control", "weather_type": "spore_season"}]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var tide_skill := {"kind": "weather_control", "weather_type": "gravity_tide"}
		var rival_weather_skill := {"kind": "weather_control", "weather_type": "spore_season"}
		var tide_plan := _ai_controller(main).call("_ai_weather_control_plan", 1, tide_skill) as Dictionary
		var rival_weather_plan := _ai_controller(main).call("_ai_weather_control_plan", 1, rival_weather_skill) as Dictionary
		var tide_context := _ai_controller(main).call("_ai_card_play_context", 1, 0, tide_skill) as Dictionary
		var rival_weather_context := _ai_controller(main).call("_ai_card_play_context", 1, 1, rival_weather_skill) as Dictionary
		var tide_ok := not tide_plan.is_empty() \
			and String(tide_plan.get("weather_type", "")) == "gravity_tide" \
			and String(tide_plan.get("weather_plan_role", "")) == "boost_own_route" \
			and int(tide_plan.get("target_owner", -1)) == 1 \
			and int(tide_plan.get("weather_own_value", 0)) > 0 \
			and int(tide_context.get("weather_plan_score", 0)) > 0
		var rival_weather_ok := not rival_weather_plan.is_empty() \
			and String(rival_weather_plan.get("weather_type", "")) == "spore_season" \
			and String(rival_weather_plan.get("weather_plan_role", "")) == "suppress_rival_city" \
			and int(rival_weather_plan.get("target_owner", -1)) == 2 \
			and int(rival_weather_plan.get("weather_rival_value", 0)) > 0 \
			and int(rival_weather_context.get("weather_plan_score", 0)) > 0
		var queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, tide_context, [tide_context, rival_weather_context])) if tide_ok else false
		var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var memory_ok := queued \
			and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "policy_kind", "weather_control_gravity_tide") \
			and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "weather_plan_role", "boost_own_route")
		if not tide_ok:
			failures.append("tide plan=%s context=%s" % [str(tide_plan), str(tide_context)])
		if not rival_weather_ok:
			failures.append("rival weather plan=%s context=%s" % [str(rival_weather_plan), str(rival_weather_context)])
		if not memory_ok:
			failures.append("weather memory queued=%s" % str(queued))
		ok = ok and tide_ok and rival_weather_ok and memory_ok
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	if not failures.is_empty():
		print("AI weather control failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _verify_ai_strategy_route_diversification_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	var failures := []
	var cases := [
		{
			"label": "defense",
			"card": "应急修复1",
			"expected_kind": "route_insurance",
			"expected_route": "city_growth",
			"expected_owner": 1,
			"intent": "defend_routes",
			"stage": "defend_route",
		},
		{
			"label": "suppression",
			"card": "竞争封锁1",
			"expected_kind": "region_economy_shift",
			"expected_route": "monster_pressure",
			"expected_owner": 2,
			"intent": "disrupt_competitors",
			"stage": "attack_rival",
		},
		{
			"label": "finance",
			"card": "城市做空1",
			"expected_kind": "city_gdp_derivative",
			"expected_policy": "city_gdp_derivative_down",
			"expected_route": "finance_speculation",
			"expected_owner": 2,
			"intent": "disrupt_competitors",
			"stage": "attack_rival",
		},
		{
			"label": "intel",
			"card": "线索悬赏1",
			"expected_kind": "intel_card_trace",
			"expected_route": "intel_supply",
			"expected_owner": -999,
			"intent": "grow_focus",
			"stage": "create_demand",
			"needs_trace": true,
		},
	]
	for case_variant in cases:
		var case := case_variant as Dictionary
		var restore_case := int(main.call("_apply_run_state", saved))
		if restore_case != OK:
			failures.append("%s restore" % String(case.get("label", "")))
			ok = false
			continue
		main.set("ai_card_decision_enabled", true)
		main.set("active_card_resolution", {})
		main.set("card_resolution_queue", [])
		main.set("next_card_resolution_queue", [])
		_reset_contract_runtime(main)
		main.set("card_resolution_batch_locked", false)
		main.set("card_resolution_auction_open", false)
		main.set("card_resolution_simultaneous_timer", 0.5)
		main.set("selected_card_resolution_id", -1)
		main.set("resolved_card_history", [])
		_reset_route_plan_sandbox_for_test(main)
		var own_index := _first_empty_land_district_for_contract(main)
		var rival_index := _first_empty_land_district_for_contract(main, [own_index])
		if own_index < 0 or rival_index < 0:
			failures.append("%s missing city slots" % String(case.get("label", "")))
			ok = false
			continue
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 6600 if player_index == 1 else (10700 if player_index == 2 else 1000)
			player["action_cooldown"] = 0.0
			if player_index == 1:
				var memory := _ai_controller(main).call("_empty_ai_memory") as Dictionary
				memory["economic_focus_product"] = "环晶电池"
				memory["economic_focus_score"] = 800
				memory["strategy_intent"] = String(case.get("intent", "grow_focus"))
				memory["strategy_score"] = 900
				memory["route_plan_product"] = "环晶电池"
				memory["route_plan_stage"] = String(case.get("stage", "create_demand"))
				memory["route_plan_score"] = 900
				player["ai_memory"] = memory
				var skill := main.call("_make_skill", String(case.get("card", ""))) as Dictionary
				skill.erase("starter_play_free")
				player["slots"] = [skill]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var own_created := CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI路线分化自城")
		var rival_created := CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI路线分化竞城")
		var own_goods := _set_city_products_and_demands_for_test(
			main,
			own_index,
			["环晶电池", "光合凝胶", "轨迹墨水", "活体芯片", "离岸水晶"],
			["环晶电池", "轨迹墨水", "活体芯片"],
			2
		) if own_created else false
		var rival_goods := _set_city_products_and_demands_for_test(
			main,
			rival_index,
			["环晶电池", "星尘香料"],
			["轨迹墨水"],
			2
		) if rival_created else false
		if not (own_created and rival_created and own_goods and rival_goods):
			failures.append("%s city setup" % String(case.get("label", "")))
			ok = false
			continue
		var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var own_district := districts[own_index] as Dictionary
		var own_city := own_district.get("city", {}) as Dictionary
		own_city["trade_route_damage"] = 2
		own_city["trade_disrupted_routes"] = 2
		own_city["last_income"] = 720
		own_district["damage"] = 2
		own_district["panic"] = 16
		own_district["city"] = own_city
		districts[own_index] = own_district
		var rival_district := districts[rival_index] as Dictionary
		var rival_city := rival_district.get("city", {}) as Dictionary
		rival_city["trade_route_damage"] = 3
		rival_city["trade_disrupted_routes"] = 3
		rival_city["last_income"] = 920
		rival_district["damage"] = 4
		rival_district["panic"] = 36
		rival_district["city"] = rival_city
		districts[rival_index] = rival_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
		main.call("_refresh_city_networks")
		if bool(case.get("needs_trace", false)):
			var history := [{
				"resolution_id": 88001,
				"queued_order": 88001,
				"player_index": 2,
				"skill": main.call("_make_skill", "城市融资1"),
				"selected_district": rival_index,
				"play_requirement_product": "活体芯片",
				"play_requirement_flow": 1,
				"public_owner_revealed": false,
				"resolved_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
			}]
			main.set("resolved_card_history", history)
			main.set("selected_card_resolution_id", 88001)
		var skill_for_context := main.call("_make_skill", String(case.get("card", ""))) as Dictionary
		skill_for_context.erase("starter_play_free")
		var context := _ai_controller(main).call("_ai_card_play_context", 1, 0, skill_for_context) as Dictionary
		var candidates := _ai_controller(main).call("_ai_card_play_candidates", 1) as Array
		var choice := _find_ai_play_candidate_by_card(candidates, String(case.get("card", "")))
		var label := String(case.get("label", "route"))
		var expected_kind := String(case.get("expected_kind", ""))
		var expected_route := String(case.get("expected_route", ""))
		var expected_owner := int(case.get("expected_owner", -999))
		var case_ok := not context.is_empty() and not choice.is_empty()
		case_ok = case_ok and String(choice.get("kind", "")) == expected_kind
		case_ok = case_ok and String(choice.get("development_route", "")) == expected_route
		case_ok = case_ok and int(choice.get("generic_effect_bonus", 0)) > 0
		if expected_owner != -999:
			case_ok = case_ok and int(choice.get("target_owner", -999)) == expected_owner
		if case.has("expected_policy"):
			case_ok = case_ok and String(choice.get("policy_kind", "")) == String(case.get("expected_policy", ""))
		var queued := bool(_ai_controller(main).call("_ai_queue_play_candidate", 1, choice, candidates)) if not choice.is_empty() else false
		var players_after := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var memory_ok := queued and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "development_route", expected_route)
		if case.has("expected_policy"):
			memory_ok = memory_ok and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "policy_kind", String(case.get("expected_policy", "")))
		else:
			memory_ok = memory_ok and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "policy_kind", expected_kind)
		if not (case_ok and queued and memory_ok):
			failures.append("%s context=%s choice=%s kind=%s route=%s owner=%d generic=%d score=%d phase=%d queued=%s memory=%s" % [
				label,
				str(not context.is_empty()),
				str(not choice.is_empty()),
				String(choice.get("kind", "")),
				String(choice.get("development_route", "")),
				int(choice.get("target_owner", -999)),
				int(choice.get("generic_effect_bonus", 0)),
				int(choice.get("score", 0)),
				int(choice.get("phase_bonus", 0)),
				str(queued),
				str(memory_ok),
			])
			ok = false
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	if not failures.is_empty():
		print("AI strategy route diversification failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _drain_card_resolution_queue_for_test(main: Node, max_steps: int = 80) -> void:
	for _i in range(max_steps):
		_advance_card_resolution_frame_for_test(main, 1.0)
		if _as_array(main.get("card_resolution_queue")).is_empty() \
			and _as_array(main.get("next_card_resolution_queue")).is_empty() \
			and (main.get("active_card_resolution") as Dictionary).is_empty():
			return


func _seed_supply_cards_near_ai_monsters_for_test(main: Node) -> void:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var supply_cards := [
		"城市融资1",
		"供应链保险1",
		"交通升级1",
		"区域供需合约1",
		"自动撮合合约1",
		"价格套利1",
		"城市做空1",
		"商品看涨1",
		"商路黑客1",
		"诱导电波1",
		"线索悬赏1",
		"业主透镜1",
		"远程补给链1",
		"星链拆解1",
		"产权冻结1",
	]
	var support_products := ["环晶电池", "轨迹墨水", "活体芯片", "轨道盆栽", "离岸水晶"]
	for actor_variant in _as_array(main.get("auto_monsters")):
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var origin := int(actor.get("position", -1))
		if origin < 0 or origin >= districts.size():
			continue
		var indices := [origin]
		for neighbor_variant in _as_array((districts[origin] as Dictionary).get("neighbors", [])):
			var neighbor := int(neighbor_variant)
			if neighbor >= 0 and neighbor < districts.size() and not indices.has(neighbor):
				indices.append(neighbor)
		for district_index_variant in indices:
			var district_index := int(district_index_variant)
			var district := districts[district_index] as Dictionary
			district["card_choices"] = supply_cards.duplicate()
			var products := _as_string_array(_as_array(district.get("products", [])))
			var demands := _as_string_array(_as_array(district.get("demands", [])))
			for product_variant in support_products:
				var product_name := String(product_variant)
				if not products.has(product_name):
					products.append(product_name)
				if not demands.has(product_name):
					demands.append(product_name)
			district["products"] = products
			district["demands"] = demands
			var sources := {}
			for card_variant in supply_cards:
				sources[String(card_variant)] = "烟测补给:%s" % String(district.get("name", "区域"))
			district["card_sources"] = sources
			districts[district_index] = district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts


func _ai_owned_monster_owner_count(main: Node, owner_index: int) -> int:
	var count := 0
	for actor_variant in _as_array(main.get("auto_monsters")):
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		if int(actor.get("owner", -1)) == owner_index and not bool(actor.get("down", false)):
			count += 1
	return count


func _force_ai_cities_to_shared_goods(main: Node) -> void:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	for player_index in range(1, players.size()):
		for city_index_variant in _as_array(_ai_controller(main).call("_active_city_indices_for_player", player_index)):
			_set_city_products_and_demands_for_test(
				main,
				int(city_index_variant),
				["环晶电池", "轨迹墨水", "活体芯片", "光合凝胶", "离岸水晶", "轨道盆栽"],
				["轨迹墨水", "活体芯片", "环晶电池", "光合凝胶", "离岸水晶"],
				2
			)
	main.call("_refresh_city_networks")


func _force_ai_opening_purchases_for_test(main: Node, max_players: int) -> Dictionary:
	var bought := {}
	for player_index in range(1, max_players):
		var candidates := _as_array(_ai_controller(main).call("_ai_card_buy_candidates", player_index))
		while not candidates.is_empty():
			var best_index := -1
			var best_score := -999999
			for i in range(candidates.size()):
				if not (candidates[i] is Dictionary):
					continue
				var candidate := candidates[i] as Dictionary
				var score := int(candidate.get("score", 0))
				if score > best_score:
					best_score = score
					best_index = i
			if best_index < 0:
				break
			var choice := candidates[best_index] as Dictionary
			var district_index := int(choice.get("district", -1))
			var card_name := String(choice.get("card_name", ""))
			if bool(main.call("_buy_card_for_player_from_district", player_index, district_index, card_name, true, true, int(choice.get("discard_slot", -1)))):
				bought[player_index] = true
				break
			candidates.remove_at(best_index)
	return bought


func _exercise_ai_primary_route_cards_for_test(main: Node) -> Array:
	var failures := []
	var route_cards := {
		0: "城市融资1",
		1: "商品看涨1",
		2: "产权冻结1",
		3: "诱导电波1",
		4: "区域供需合约1",
		5: "线索悬赏1",
	}
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	for player_index in range(1, players.size()):
		var player := players[player_index] as Dictionary
		var profile := player.get("ai_profile", {}) as Dictionary
		var profile_index := int(profile.get("profile_index", -1))
		if not route_cards.has(profile_index):
			continue
		var card_name := String(route_cards[profile_index])
		var skill := main.call("_make_skill", card_name) as Dictionary
		skill.erase("starter_play_free")
		player["slots"] = [skill]
		player["cash"] = maxi(int(player.get("cash", 0)), 9000)
		player["action_cooldown"] = 0.0
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var clue_city_index := -1
	for i in range(districts.size()):
		var city := (districts[i] as Dictionary).get("city", {}) as Dictionary
		if not city.is_empty() and bool(city.get("active", false)) and not bool(city.get("destroyed", false)) and int(city.get("owner", -1)) > 0:
			clue_city_index = i
			break
	if clue_city_index >= 0:
		main.set("resolved_card_history", [{
			"resolution_id": 99041,
			"queued_order": 99041,
			"player_index": 2,
			"skill": main.call("_make_skill", "城市融资1"),
			"selected_district": clue_city_index,
			"play_requirement_product": "活体芯片",
			"play_requirement_flow": 1,
			"public_owner_revealed": false,
			"resolved_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
		}])
		main.set("selected_card_resolution_id", 99041)
	for player_index in range(1, players.size()):
		players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		var player := players[player_index] as Dictionary
		var profile := player.get("ai_profile", {}) as Dictionary
		var profile_index := int(profile.get("profile_index", -1))
		if not route_cards.has(profile_index):
			continue
		var expected_card := String(route_cards[profile_index])
		player["action_cooldown"] = 0.0
		players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var result := String(_ai_controller(main).call("_ai_execute_card_turn", player_index, true))
		if result != "play":
			var candidates := _ai_controller(main).call("_ai_card_play_candidates", player_index) as Array
			var choice := _find_ai_play_candidate_by_card(candidates, expected_card)
			failures.append("primary route play p%d %s result=%s choice=%s candidates=%d" % [
				player_index,
				expected_card,
				result,
				str(not choice.is_empty()),
				candidates.size(),
			])
			continue
		_ai_controller(main).call("_auto_ai_auction_bids", true)
		_drain_card_resolution_queue_for_test(main, 160)
	return failures


func _clear_ai_cooldowns_for_test(main: Node) -> void:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	for player_index in range(1, players.size()):
		var player := players[player_index] as Dictionary
		player["action_cooldown"] = 0.0
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _verify_ai_progresses_run_smoke(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var saved_force_duration := float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous := float(main.get("card_resolution_force_simultaneous_window"))
	var ok := true
	var failures := []
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	_reset_contract_runtime(main)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_force_duration", 0.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	if players.size() < EXPECTED_PLAYER_COUNT:
		failures.append("player count")
		ok = false
	else:
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 6200
			player["action_cooldown"] = 0.0
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var built := int(_ai_controller(main).call("_auto_expand_rival_syndicates", true))
		_force_ai_cities_to_shared_goods(main)
		if built < EXPECTED_AI_PLAYER_COUNT:
			failures.append("built %d" % built)
			ok = false
		for player_index in range(1, EXPECTED_PLAYER_COUNT):
			if int(main.call("_player_active_city_count", player_index)) <= 0:
				failures.append("missing city player %d" % player_index)
				ok = false
		var buy_count := 0
		var business_actions := 0
		var starting_cycle := int(main.get("business_cycle_count"))
		for _cycle in range(3):
			_clear_ai_cooldowns_for_test(main)
			for player_index in range(1, EXPECTED_PLAYER_COUNT):
				var result := String(_ai_controller(main).call("_ai_execute_card_turn", player_index, true))
				if result == "buy":
					buy_count += 1
			_ai_controller(main).call("_auto_ai_auction_bids", true)
			_drain_card_resolution_queue_for_test(main)
			business_actions += int(_ai_controller(main).call("_auto_rival_business_actions", true))
			main.call("_market_tick")
			main.call("_settle_city_cashflow_seconds", 60.0)
		var after_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var saw_income := false
		var saw_samples_for_all := true
		for player_index in range(1, EXPECTED_PLAYER_COUNT):
			var player := after_players[player_index] as Dictionary
			saw_income = saw_income or int(player.get("total_city_income", 0)) > 0
			var memory := player.get("ai_memory", {}) as Dictionary
			saw_samples_for_all = saw_samples_for_all and not _as_array(memory.get("decision_samples", [])).is_empty()
		if int(main.get("business_cycle_count")) < starting_cycle + 3:
			failures.append("cycles %d->%d" % [starting_cycle, int(main.get("business_cycle_count"))])
			ok = false
		if buy_count <= 0:
			failures.append("buy_count 0")
			ok = false
		if business_actions <= 0:
			failures.append("business_actions 0")
			ok = false
		if not saw_income:
			failures.append("no income")
			ok = false
		if not saw_samples_for_all:
			failures.append("missing samples")
			ok = false
		var coordinator := _runtime_coordinator(main)
		coordinator.call("advance_victory_control", 0.0, {})
		var victory_rankings := coordinator.call("victory_control_rankings", false) as Array
		var ai_progress_rows := 0
		for ranking_variant in victory_rankings:
			if ranking_variant is Dictionary and int((ranking_variant as Dictionary).get("player_index", -1)) > 0:
				ai_progress_rows += 1
		if ai_progress_rows < EXPECTED_AI_PLAYER_COUNT:
			failures.append("victory progress rows %d/%d" % [ai_progress_rows, EXPECTED_AI_PLAYER_COUNT])
			ok = false
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	if not failures.is_empty():
		print("AI progress smoke failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _verify_max_ai_seat_complete_smoke(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var saved_force_duration := float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous := float(main.get("card_resolution_force_simultaneous_window"))
	var ok := true
	var failures := []
	var max_players := 8
	var max_ai := 7
	var role_indices := []
	var starter_indices := []
	var catalog_size := int(main.call("_catalog_size"))
	for i in range(max_players):
		role_indices.append(i)
		starter_indices.append(i % max(1, catalog_size))
	main.set("configured_player_count", max_players)
	main.set("configured_ai_player_count", max_ai)
	main.set("configured_roguelike_depth", 5)
	main.set("configured_role_indices", role_indices)
	main.set("configured_starter_monster_indices", starter_indices)
	main.call("_new_game")
	_set_map_focus_animation_for_smoke(main, false)
	_mark_smoke_progress("max ai setup ready")
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	_reset_contract_runtime(main)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_force_duration", 0.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if players.size() != max_players:
		failures.append("players %d" % players.size())
		ok = false
	if _ai_player_count(players) != max_ai:
		failures.append("ai count %d" % _ai_player_count(players))
		ok = false
	if districts.size() < 31:
		failures.append("districts %d" % districts.size())
		ok = false
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		player["cash"] = 7600
		player["action_cooldown"] = 0.0
		players[player_index] = player
		if player_index == 0 and bool(player.get("is_ai", true)):
			failures.append("human seat ai")
			ok = false
		if player_index > 0 and not bool(player.get("is_ai", false)):
			failures.append("ai seat %d not ai" % player_index)
			ok = false
		var role := player.get("role_card", {}) as Dictionary
		var slots := _as_array(player.get("slots", []))
		if role.is_empty() or slots.is_empty():
			failures.append("missing role/slot %d" % player_index)
			ok = false
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var built := int(_ai_controller(main).call("_auto_expand_rival_syndicates", true))
	_force_ai_cities_to_shared_goods(main)
	_mark_smoke_progress("max ai cities seeded")
	if built < max_ai:
		failures.append("built %d" % built)
		ok = false
	for player_index in range(1, max_players):
		if int(main.call("_player_active_city_count", player_index)) <= 0:
			failures.append("missing city %d" % player_index)
			ok = false
	var bought := _force_ai_opening_purchases_for_test(main, max_players)
	_mark_smoke_progress("max ai forced opening buys")
	var post_opening_play_count := 0
	var business_actions := 0
	for cycle_index in range(2):
		_mark_smoke_progress("max ai cycle %d start" % (cycle_index + 1))
		_clear_ai_cooldowns_for_test(main)
		for player_index in range(1, max_players):
			var result := String(_ai_controller(main).call("_ai_execute_card_turn", player_index, true))
			if result == "buy":
				bought[player_index] = true
			elif result == "play":
				post_opening_play_count += 1
		_mark_smoke_progress("max ai cycle %d decisions" % (cycle_index + 1))
		_ai_controller(main).call("_auto_ai_auction_bids", true)
		_drain_card_resolution_queue_for_test(main, 160)
		_mark_smoke_progress("max ai cycle %d queue drained" % (cycle_index + 1))
		if cycle_index == 0:
			business_actions += int(_ai_controller(main).call("_auto_rival_business_actions", true))
		main.call("_market_tick")
		main.call("_settle_city_cashflow_seconds", 60.0)
		_mark_smoke_progress("max ai cycle %d economy settled" % (cycle_index + 1))
	_mark_smoke_progress("max ai cycles complete")
	var primary_route_failures := _exercise_ai_primary_route_cards_for_test(main)
	_mark_smoke_progress("max ai primary routes exercised")
	if not primary_route_failures.is_empty():
		failures.append_array(primary_route_failures)
		ok = false
	var after_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var saw_income := false
	var sampled_ai := 0
	for player_index in range(1, max_players):
		var player := after_players[player_index] as Dictionary
		saw_income = saw_income or int(player.get("total_city_income", 0)) > 0
		var memory := player.get("ai_memory", {}) as Dictionary
		if not _as_array(memory.get("decision_samples", [])).is_empty():
			sampled_ai += 1
	if bought.size() < max_ai:
		failures.append("bought %d" % bought.size())
		ok = false
	if post_opening_play_count <= 0:
		failures.append("post opening plays 0")
		ok = false
	if business_actions <= 0:
		failures.append("business actions 0")
		ok = false
	if not saw_income:
		failures.append("no income")
		ok = false
	if sampled_ai < max_ai:
		failures.append("sampled ai %d" % sampled_ai)
		ok = false
	var route_report := _ai_controller(main).call("_ai_profile_route_action_report") as Dictionary
	var route_summary := String(_ai_controller(main).call("_ai_profile_route_action_summary", route_report))
	_mark_smoke_progress("max ai route report")
	if int(route_report.get("profile_count", 0)) < 6:
		failures.append("route profiles %d" % int(route_report.get("profile_count", 0)))
		ok = false
	if not _as_array(route_report.get("missing_route_profiles", [])).is_empty():
		failures.append("route missing %s" % route_summary)
		ok = false
	if int(route_report.get("covered_distinct_route_count", 0)) < 4:
		failures.append("route distinct %d %s" % [int(route_report.get("covered_distinct_route_count", 0)), route_summary])
		ok = false
	if int(route_report.get("primary_covered_profile_count", 0)) < 4:
		failures.append("route primary %d %s" % [int(route_report.get("primary_covered_profile_count", 0)), route_summary])
		ok = false
	var live_route_report := _ai_controller(main).call("_ai_live_route_balance_report") as Dictionary
	var live_route_summary := String(_ai_controller(main).call("_ai_live_route_balance_summary", live_route_report))
	_mark_smoke_progress("max ai live route report")
	if not bool(live_route_report.get("ok", false)):
		failures.append("live route audit %s" % live_route_summary)
		ok = false
	if int(live_route_report.get("route_sample_ai_count", 0)) < max_ai:
		failures.append("live route ai %d %s" % [int(live_route_report.get("route_sample_ai_count", 0)), live_route_summary])
		ok = false
	if int(live_route_report.get("money_progress_ai_count", 0)) < max_ai - 1:
		failures.append("live route money %d %s" % [int(live_route_report.get("money_progress_ai_count", 0)), live_route_summary])
		ok = false
	if int(live_route_report.get("covered_core_route_count", 0)) < 4:
		failures.append("live route core %d %s" % [int(live_route_report.get("covered_core_route_count", 0)), live_route_summary])
		ok = false
	if int(live_route_report.get("primary_route_player_count", 0)) < 4:
		failures.append("live route primary %d %s" % [int(live_route_report.get("primary_route_player_count", 0)), live_route_summary])
		ok = false
	if int(live_route_report.get("action_kind_count", 0)) < 3:
		failures.append("live route actions %d %s" % [int(live_route_report.get("action_kind_count", 0)), live_route_summary])
		ok = false
	var route_viability_report := _ai_controller(main).call("_ai_route_viability_report") as Dictionary
	var route_viability_summary := String(_ai_controller(main).call("_ai_route_viability_summary", route_viability_report))
	_mark_smoke_progress("max ai route viability report")
	if not bool(route_viability_report.get("ok", false)):
		failures.append("route viability audit %s" % route_viability_summary)
		ok = false
	if int(route_viability_report.get("viable_required_route_count", 0)) < int(route_viability_report.get("minimum_viable_required_routes", 5)):
		failures.append("route viability count %d/%d %s" % [
			int(route_viability_report.get("viable_required_route_count", 0)),
			int(route_viability_report.get("minimum_viable_required_routes", 5)),
			route_viability_summary,
		])
		ok = false
	if not _as_array(route_viability_report.get("missing_required_routes", [])).is_empty():
		failures.append("route viability missing %s %s" % [
			"、".join(_as_array(route_viability_report.get("missing_required_routes", []))),
			route_viability_summary,
		])
		ok = false
	var product_bridge_report := _ai_controller(main).call("_ai_product_route_bridge_report") as Dictionary
	var product_bridge_summary := String(_ai_controller(main).call("_ai_product_route_bridge_summary", product_bridge_report))
	_mark_smoke_progress("max ai product bridge report")
	if not bool(product_bridge_report.get("ok", false)):
		failures.append("product route bridge audit %s" % product_bridge_summary)
		ok = false
	if int(product_bridge_report.get("product_sample_ai_count", 0)) < max_ai:
		failures.append("product route bridge ai %d %s" % [int(product_bridge_report.get("product_sample_ai_count", 0)), product_bridge_summary])
		ok = false
	if int(product_bridge_report.get("distinct_product_count", 0)) < 4:
		failures.append("product route bridge goods %d %s" % [int(product_bridge_report.get("distinct_product_count", 0)), product_bridge_summary])
		ok = false
	if int(product_bridge_report.get("route_stage_count", 0)) < 2:
		failures.append("product route bridge stages %d %s" % [int(product_bridge_report.get("route_stage_count", 0)), product_bridge_summary])
		ok = false
	if int(product_bridge_report.get("development_route_count", 0)) < 3:
		failures.append("product route bridge development routes %d %s" % [int(product_bridge_report.get("development_route_count", 0)), product_bridge_summary])
		ok = false
	if int(product_bridge_report.get("policy_family_count", 0)) < 3:
		failures.append("product route bridge families %d %s" % [int(product_bridge_report.get("policy_family_count", 0)), product_bridge_summary])
		ok = false
	var profile_identity_report := _ai_controller(main).call("_ai_profile_strategy_identity_report") as Dictionary
	var profile_identity_summary := String(_ai_controller(main).call("_ai_profile_strategy_identity_summary", profile_identity_report))
	_mark_smoke_progress("max ai profile identity report")
	if not bool(profile_identity_report.get("ok", false)):
		failures.append("profile identity audit %s" % profile_identity_summary)
		ok = false
	if int(profile_identity_report.get("simulated_profile_count", 0)) < 6:
		failures.append("profile identity simulated %d %s" % [int(profile_identity_report.get("simulated_profile_count", 0)), profile_identity_summary])
		ok = false
	if int(profile_identity_report.get("identity_profile_count", 0)) < 6:
		failures.append("profile identity ready %d %s" % [int(profile_identity_report.get("identity_profile_count", 0)), profile_identity_summary])
		ok = false
	if int(profile_identity_report.get("distinct_primary_route_count", 0)) < 5:
		failures.append("profile identity routes %d %s" % [int(profile_identity_report.get("distinct_primary_route_count", 0)), profile_identity_summary])
		ok = false
	if int(profile_identity_report.get("expected_family_covered_count", 0)) < 4:
		failures.append("profile identity families %d %s" % [int(profile_identity_report.get("expected_family_covered_count", 0)), profile_identity_summary])
		ok = false
	if int(profile_identity_report.get("signature_family_covered_count", 0)) < 3:
		failures.append("profile identity signatures %d %s" % [int(profile_identity_report.get("signature_family_covered_count", 0)), profile_identity_summary])
		ok = false
	if int(profile_identity_report.get("signature_bonus_profile_count", 0)) < 6:
		failures.append("profile identity signature bonus %d %s" % [int(profile_identity_report.get("signature_bonus_profile_count", 0)), profile_identity_summary])
		ok = false
	var leader_index := 1
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		player["cash"] = 120000 if player_index == leader_index else 400
		player["eliminated"] = false
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var coordinator := _runtime_coordinator(main)
	coordinator.call("reset_victory_control_runtime")
	var outcome_receipt := coordinator.call("resolve_victory_outcome", "planet_destroyed") as Dictionary
	_mark_smoke_progress("max ai victory receipt settled")
	if String(outcome_receipt.get("reason_code", "")) != "planet_destroyed" \
		or (outcome_receipt.get("winner_player_indices", []) as Array) != [leader_index] \
		or not bool(main.call("_runtime_session_finished")):
		failures.append("victory receipt mismatch %s" % str(outcome_receipt))
		ok = false
	var standings_text := String((main.call("_standings_public_snapshot") as Dictionary).get("summary_text", ""))
	if not standings_text.contains("终局总结") or not standings_text.contains("公开线索") or standings_text.contains("对手计划") or standings_text.contains("内部决策") or standings_text.contains("AI路线") or standings_text.contains("发展路线") or not standings_text.contains("关键卡牌") or not standings_text.contains("玩家概览") or not standings_text.contains("城收") or not standings_text.contains("情报"):
		failures.append("missing final summary")
		ok = false
	var final_menu_title := _menu_overlay_node(main, "MenuTitleLabel") as Label
	var final_menu_preview := _menu_overlay_node(main, "MenuPreviewBox") as VBoxContainer
	if final_menu_title == null or final_menu_title.text != "终局结算":
		failures.append("missing final settlement menu")
		ok = false
	if final_menu_preview == null or not _container_button_text_contains(final_menu_preview, "查看局势排名") or not _container_button_text_contains(final_menu_preview, "打开经济总览") or not _container_button_text_contains(final_menu_preview, "开局准备"):
		failures.append("missing final settlement menu actions")
		ok = false
	if final_menu_preview == null or not _container_label_text_contains(final_menu_preview, "终局速览") or not _container_label_text_contains(final_menu_preview, "胜者") or not _container_label_text_contains(final_menu_preview, "钱从哪里来") or not _container_label_text_contains(final_menu_preview, "关键影响"):
		failures.append("missing final settlement summary cards")
		ok = false
	var finalized_ai := 0
	var final_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	for player_index in range(1, max_players):
		var memory := (final_players[player_index] as Dictionary).get("ai_memory", {}) as Dictionary
		if int(memory.get("episode_learning_updates", 0)) > 0:
			finalized_ai += 1
	if finalized_ai < max_ai:
		failures.append("finalized ai %d" % finalized_ai)
		ok = false
	var restore_result := int(main.call("_apply_run_state", saved))
	_set_map_focus_animation_for_smoke(main, true)
	_mark_smoke_progress("max ai restored")
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	if not failures.is_empty():
		print("Max AI seat smoke failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _set_map_focus_animation_for_smoke(main: Node, enabled: bool) -> void:
	var map_view := main.get("map_view") as Control
	if map_view != null and map_view.has_method("set_programmatic_focus_animation_enabled"):
		map_view.call("set_programmatic_focus_animation_enabled", enabled)
	var full_map_view := main.get("full_map_view") as Control
	if full_map_view != null and full_map_view.has_method("set_programmatic_focus_animation_enabled"):
		full_map_view.call("set_programmatic_focus_animation_enabled", enabled)


func _starting_monster_cards_match_configured_choices(main: Node, players: Array) -> bool:
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		var slots := _as_array(player.get("slots", []))
		if role.is_empty() or slots.is_empty() or slots[0] == null:
			return false
		var starter := slots[0] as Dictionary
		var expected_index := int(main.call("_configured_starter_monster_index", player_index))
		var expected_name := String(main.call("_monster_card_name", expected_index, 1))
		if String(starter.get("name", "")) != expected_name:
			return false
		for starter_field in ["starter_monster_index", "starter_monster_name", "starter_monster_card", "starter_hp_bonus", "starter_duration_bonus", "starter_move_multiplier", "starter_fixed_skill_bonus"]:
			if role.has(starter_field):
				return false
		if starter.has("source_role") or starter.has("starter_role_index") or starter.has("role_passive_summary"):
			return false
	return not players.is_empty()


func _all_monster_cards_have_field_attributes(main: Node) -> bool:
	var total := 0
	var finite_duration_count := 0
	var land_zone_count := 0
	var ocean_zone_count := 0
	for catalog_index in range(int(main.call("_catalog_size"))):
		for rank in range(1, 5):
			var card := main.call("_make_skill", main.call("_monster_card_name", catalog_index, rank)) as Dictionary
			total += 1
			if int(card.get("hp", 0)) <= 0:
				return false
			if float(card.get("move", 0.0)) <= 0.0:
				return false
			if not card.has("duration") or not card.has("summon_access"):
				return false
			if float(card.get("duration", -1.0)) >= 0.0:
				finite_duration_count += 1
			match String(card.get("summon_access", "")):
				"land_monster_zone":
					land_zone_count += 1
				"ocean_monster_zone":
					ocean_zone_count += 1
	return total > 0 and finite_duration_count * 2 > total and land_zone_count > 0 and ocean_zone_count > 0


func _verify_weather_forecast_system(main: Node) -> bool:
	var ok := true
	var runtime_coordinator := _runtime_coordinator(main)
	var weather := _weather_controller(main)
	if runtime_coordinator == null or weather == null:
		return false
	var saved_weather := runtime_coordinator.call("weather_to_save_data") as Dictionary
	var saved_clock := {}
	if runtime_coordinator.has_method("world_effective_clock_snapshot"):
		saved_clock = runtime_coordinator.call("world_effective_clock_snapshot") as Dictionary
	var district_index := _first_alive_district_index_for_test(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts))
	if district_index < 0:
		return false
	runtime_coordinator.call("apply_weather_save_data", {})
	if runtime_coordinator.has_method("restore_world_effective_seconds"):
		runtime_coordinator.call("restore_world_effective_seconds", 0.0)
	var scheduled: bool = bool(weather.call("schedule_forecast", "ion_storm", district_index, 1, 30.0, 45.0, "smoke", false))
	var public_snapshot := weather.call("public_snapshot") as Dictionary
	var events := _as_array(public_snapshot.get("events", []))
	ok = ok and bool(scheduled) and events.size() == 1
	ok = ok and int((public_snapshot.get("timing", {}) as Dictionary).get("forecast_min_seconds", -1)) == 30
	ok = ok and int((public_snapshot.get("timing", {}) as Dictionary).get("forecast_max_seconds", -1)) == 60
	ok = ok and int((public_snapshot.get("timing", {}) as Dictionary).get("active_min_seconds", -1)) == 45
	ok = ok and int((public_snapshot.get("timing", {}) as Dictionary).get("active_max_seconds", -1)) == 90
	ok = ok and int((public_snapshot.get("timing", {}) as Dictionary).get("fade_seconds", -1)) == 10
	ok = ok and int((public_snapshot.get("timing", {}) as Dictionary).get("max_unended_events", -1)) == 2
	if not events.is_empty():
		var event := events[0] as Dictionary
		var affected := _as_array(event.get("region_indices", event.get("districts", [])))
		var forecast_us := int(event.get("forecast_starts_at_world_us", -1))
		var active_us := int(event.get("active_starts_at_world_us", -1))
		var active_end_us := int(event.get("active_ends_at_world_us", -1))
		var fade_end_us := int(event.get("fade_ends_at_world_us", -1))
		ok = ok and String(event.get("type", "")) == "ion_storm"
		ok = ok and affected == [district_index]
		ok = ok and active_us - forecast_us >= 30_000_000 and active_us - forecast_us <= 60_000_000
		ok = ok and active_end_us - active_us >= 45_000_000 and active_end_us - active_us <= 90_000_000
		ok = ok and fade_end_us - active_end_us == 10_000_000
		if runtime_coordinator.has_method("restore_world_effective_seconds"):
			runtime_coordinator.call("restore_world_effective_seconds", float(active_us) / 1_000_000.0)
		weather.call("tick", 0.0)
		var active := _as_array(weather.call("active_zones_snapshot"))
		ok = ok and active.size() == 1
		var region_effect := weather.call("region_effect_snapshot", district_index) as Dictionary
		ok = ok and not _as_array(region_effect.get("effects", [])).is_empty()
		main.call("_refresh_ui")
		var weather_forecast_strip := main.find_child("WeatherForecastStrip", true, false) as Control
		var weather_layer := main.find_child("WeatherLayer", true, false) as Control
		if weather_layer == null:
			weather_layer = main.find_child("WeatherMapOverlay", true, false) as Control
		ok = ok and weather_forecast_strip != null and weather_layer != null
		if runtime_coordinator.has_method("restore_world_effective_seconds"):
			runtime_coordinator.call("restore_world_effective_seconds", float(fade_end_us) / 1_000_000.0)
		weather.call("tick", 0.0)
		var post_fade_events := _as_array((weather.call("public_snapshot") as Dictionary).get("events", []))
		ok = ok and post_fade_events.is_empty()
	var restore_clock_ok := true
	if not saved_clock.is_empty() and runtime_coordinator.has_method("restore_world_effective_seconds"):
		var clock_restore := runtime_coordinator.call("restore_world_effective_seconds", float(saved_clock.get("world_effective_seconds", 0.0))) as Dictionary
		restore_clock_ok = not clock_restore.is_empty()
	var restore_result := runtime_coordinator.call("apply_weather_save_data", saved_weather) as Dictionary
	main.call("_refresh_ui")
	return ok and restore_clock_ok and bool(restore_result.get("applied", false))


func _verify_news_and_weather_card_rules(main: Node) -> bool:
	var ok := true
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var district_index := -1
	for i in range(districts.size()):
		var district := districts[i] as Dictionary
		if not bool(district.get("destroyed", false)):
			district_index = i
			break
	if district_index < 0:
		return false
	var runtime_coordinator := _runtime_coordinator(main)
	var weather := _weather_controller(main)
	if runtime_coordinator == null or weather == null:
		return false
	var saved_weather := runtime_coordinator.call("weather_to_save_data") as Dictionary
	var saved_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var saved_selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	var news_skill := main.call("_make_skill", "热搜推送1") as Dictionary
	var weather_skill := {"weather_type": "ion_storm", "source_type": "card", "effect": "weather_control"}
	ok = ok and String(main.call("_card_codex_filter_label", "news")) == "新闻事件"
	ok = ok and String(main.call("_card_codex_filter_label", "weather")) == "天气干预"
	ok = ok and _card_presentation_category_id(main, news_skill) == "news"
	ok = ok and _card_presentation_text(main, news_skill, "strategy_route_label").contains("新闻信息战")
	var news_plan := runtime_coordinator.call("plan_card_economy_product_route_effect", {
		"handler_id": "news_event",
		"active_entry": {"resolution_id": 4406, "player_index": 0},
		"skill": news_skill,
	}) as Dictionary
	ok = ok and bool(news_plan.get("ready", false)) and String(news_plan.get("family_id", "")) == "economy"
	runtime_coordinator.call("apply_weather_save_data", {})
	ok = ok and bool(weather.call("apply_weather_control_at", weather_skill, district_index))
	var forecast := weather.call("forecast_snapshot") as Dictionary
	ok = ok and forecast != null and not forecast.is_empty()
	ok = ok and String(forecast.get("source_type", "")) == "card"
	ok = ok and String(forecast.get("type", "")) == "ion_storm"
	ok = ok and _as_array(forecast.get("region_indices", forecast.get("districts", []))) == [district_index]
	ok = ok and int(forecast.get("active_starts_at_world_us", 0)) - int(forecast.get("forecast_starts_at_world_us", 0)) >= 30_000_000
	var restore_weather := runtime_coordinator.call("apply_weather_save_data", saved_weather) as Dictionary
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = saved_selected_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = saved_selected_player
	main.call("_refresh_ui")
	return ok and bool(restore_weather.get("applied", false))


func _verify_monster_card_terrain_restriction(main: Node, players: Array, districts: Array) -> bool:
	if players.is_empty() or districts.is_empty():
		return false
	var ocean_index := _first_terrain_district(districts, "ocean")
	if ocean_index < 0:
		return false
	var land_card := main.call("_make_skill", main.call("_monster_card_name", 1, 1)) as Dictionary
	if String(land_card.get("summon_access", "")) != "land_monster_zone":
		return false
	if not String(main.call("_monster_card_region_text", land_card)).contains("陆地"):
		return false
	if not _card_presentation_text(main, land_card, "art_stats").contains("陆地怪区"):
		return false
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var previous_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var previous_selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	var temp_actor := _monster_controller(main).call("_make_auto_monster", previous_monsters.size(), 0, ocean_index, 0, 1) as Dictionary
	main.set("auto_monsters", [temp_actor])
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = ocean_index
	var rejected := not bool(_monster_controller(main).call("_summon_monster_from_card", players[0] as Dictionary, land_card))
	var monster_count_after := _as_array(main.get("auto_monsters")).size()
	main.set("auto_monsters", previous_monsters)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
	return rejected and monster_count_after == 1


func _summon_starting_monsters_for_smoke(main: Node, count: int) -> void:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if players.is_empty() or districts.is_empty():
		return
	var landing := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	if landing < 0 or landing >= districts.size():
		landing = 0
	for i in range(min(count, players.size())):
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = i
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = landing
		_clear_player_cooldown(main, i)
		main.call("_use_skill", 0)
		_clear_player_cooldown(main, i)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = landing
	_clear_player_cooldown(main, 0)


func _summoned_monsters_have_hidden_owners(auto_monsters: Array) -> bool:
	for actor_variant in auto_monsters:
		var actor := actor_variant as Dictionary
		if int(actor.get("owner", -1)) < 0:
			return false
		if bool(actor.get("owner_revealed", false)):
			return false
		if int(actor.get("hp", 0)) <= 0:
			return false
		if float(actor.get("remaining_time", 0.0)) <= 0.0:
			return false
	return not auto_monsters.is_empty()


func _verify_monster_owner_damage_cash_clue(main: Node) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	if previous_players.is_empty() or previous_monsters.is_empty():
		return false
	var players := previous_players.duplicate(true)
	var player := players[0] as Dictionary
	player["cash"] = 5000
	player["economic_ledger"] = []
	player["cash_history"] = [5000]
	players[0] = player
	var monsters := previous_monsters.duplicate(true)
	var actor := monsters[0] as Dictionary
	actor["owner"] = 0
	actor["owner_revealed"] = false
	actor["owner_clue"] = ""
	actor["down"] = false
	actor["armor"] = 0
	actor["hp"] = 100
	actor["max_hp"] = 100
	actor["owner_damage_cash_total"] = 1000
	actor["owner_damage_cash_lost"] = 0
	actor["owner_damage_cash_pool"] = 1000
	monsters[0] = actor
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	main.set("auto_monsters", monsters)
	_monster_controller(main).call("_auto_monster_take_damage", 0, 10, "烟测资金线索A", -1)
	_monster_controller(main).call("_auto_monster_take_damage", 0, 10, "烟测资金线索B", -1)
	var after_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_monsters := _as_array(main.get("auto_monsters"))
	var after_player := after_players[0] as Dictionary
	var after_actor := after_monsters[0] as Dictionary
	var economy_text := String((main.call("_economy_dashboard_public_snapshot") as Dictionary).get("summary_text", ""))
	var ledger := _as_array(after_player.get("economic_ledger", []))
	var cash_loss_entries := 0
	for entry_variant in ledger:
		var entry := entry_variant as Dictionary
		if String(entry.get("kind", "")) == "怪兽伤害暴露" and int(entry.get("amount", 0)) == -100:
			cash_loss_entries += 1
	var result := int(after_player.get("cash", 0)) == 4800 \
		and int(after_actor.get("owner_damage_cash_lost", 0)) == 200 \
		and int(after_actor.get("owner_damage_cash_pool", -1)) == 800 \
		and bool(after_actor.get("owner_revealed", false)) \
		and String(after_actor.get("owner_clue", "")).contains(String(after_player.get("name", "玩家1"))) \
		and int(after_actor.get("last_owner_damage_cash_loss", 0)) == 100 \
		and int(after_actor.get("last_owner_damage_amount", 0)) == 10 \
		and String(after_actor.get("last_owner_damage_source", "")).contains("烟测资金线索B") \
		and economy_text.contains("最近怪兽资金线索") \
		and economy_text.contains("归属已公开") \
		and economy_text.contains("最近损失¥100/10伤害") \
		and economy_text.contains("累计损失¥200") \
		and economy_text.contains("资金池余¥800/1000") \
		and economy_text.contains("当前玩家推理板") \
		and economy_text.contains("公开怪兽归属｜玩家1×1") \
		and economy_text.contains("归属来自公开资金损失") \
		and cash_loss_entries >= 2
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	main.set("auto_monsters", previous_monsters)
	return result


func _active_bound_skill_count_for_uid(players: Array, player_index: int, monster_uid: int) -> int:
	if player_index < 0 or player_index >= players.size() or monster_uid <= 0:
		return 0
	var player := players[player_index] as Dictionary
	var count := 0
	for skill_variant in _as_array(player.get("slots", [])):
		if skill_variant == null:
			continue
		var skill := skill_variant as Dictionary
		if String(skill.get("kind", "")) == "monster_bound_action" and int(skill.get("bound_monster_uid", 0)) == monster_uid:
			count += 1
	return count


func _verify_field_monster_card_upgrade_refreshes_state(main: Node) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var previous_logs := _public_log_messages(main).duplicate(true)
	var previous_callouts := _visual_cue_array(main, "action_callouts").duplicate(true)
	var previous_selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	var previous_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	if previous_players.is_empty() or previous_monsters.is_empty():
		return false
	var monsters := previous_monsters.duplicate(true)
	var actor := monsters[0] as Dictionary
	var owner := int(actor.get("owner", -1))
	var catalog_index := int(actor.get("catalog_index", -1))
	var monster_uid := int(actor.get("uid", 0))
	if owner < 0 or owner >= previous_players.size() or catalog_index < 0 or monster_uid <= 0:
		return false
	var players := previous_players.duplicate(true)
	var player := players[owner] as Dictionary
	player["cash"] = 5000
	player["economic_ledger"] = []
	player["cash_history"] = [5000]
	players[owner] = player
	actor["owner"] = owner
	actor["rank"] = 1
	actor["down"] = false
	actor["hp"] = maxi(1, int(actor.get("hp", 10)) - 3)
	actor["remaining_time"] = 1.25
	actor["owner_revealed"] = false
	actor["owner_clue"] = ""
	actor["owner_damage_cash_total"] = 1000
	actor["owner_damage_cash_lost"] = 400
	actor["owner_damage_cash_pool"] = 600
	actor["last_owner_damage_cash_loss"] = 123
	actor["last_owner_damage_amount"] = 3
	actor["last_owner_damage_source"] = "烟测旧伤"
	monsters[0] = actor
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	main.set("auto_monsters", monsters)
	_replace_public_log_messages(main, [])
	_set_visual_cue_array(main, "action_callouts", [])
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = owner
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = -1
	var active_bound_before := _active_bound_skill_count_for_uid(players, owner, monster_uid)
	var upgrade_card := main.call("_make_skill", main.call("_monster_card_name", catalog_index, 2)) as Dictionary
	var expected_fixed_skill_count := int(upgrade_card.get("fixed_skill_count", 2))
	var expected_hp := int(upgrade_card.get("hp", 0))
	var expected_duration := float(upgrade_card.get("duration", 0.0))
	var upgraded := bool(_monster_controller(main).call("_summon_monster_from_card", players[owner] as Dictionary, upgrade_card))
	var after_monsters := _as_array(main.get("auto_monsters"))
	var after_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	if after_monsters.is_empty():
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
		main.set("auto_monsters", previous_monsters)
		_replace_public_log_messages(main, previous_logs)
		_set_visual_cue_array(main, "action_callouts", previous_callouts)
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
		return false
	var upgraded_actor := after_monsters[0] as Dictionary
	var total_after_upgrade := int(upgraded_actor.get("owner_damage_cash_total", 0))
	var expected_total_after_upgrade := int(main.call("_owner_damage_cash_total_for_rank", 2))
	var active_bound_after := _active_bound_skill_count_for_uid(after_players, owner, monster_uid)
	var upgrade_ok := upgraded \
		and after_monsters.size() == monsters.size() \
		and int(upgraded_actor.get("uid", -1)) == monster_uid \
		and int(upgraded_actor.get("owner", -1)) == owner \
		and int(upgraded_actor.get("rank", 0)) == 2 \
		and int(upgraded_actor.get("hp", 0)) == expected_hp \
		and int(upgraded_actor.get("max_hp", 0)) == expected_hp \
		and is_equal_approx(float(upgraded_actor.get("duration", 0.0)), expected_duration) \
		and is_equal_approx(float(upgraded_actor.get("remaining_time", 0.0)), expected_duration) \
		and not bool(upgraded_actor.get("owner_revealed", true)) \
		and total_after_upgrade == expected_total_after_upgrade \
		and int(upgraded_actor.get("owner_damage_cash_lost", -1)) == 0 \
		and int(upgraded_actor.get("owner_damage_cash_pool", -1)) == total_after_upgrade \
		and int(upgraded_actor.get("last_owner_damage_cash_loss", -1)) == 0 \
		and active_bound_after >= expected_fixed_skill_count \
		and active_bound_after >= active_bound_before \
		and _callouts_contain(_visual_cue_array(main, "action_callouts"), "升级")
	var cash_before_damage := int((after_players[owner] as Dictionary).get("cash", 0))
	var max_hp := maxi(1, int(upgraded_actor.get("max_hp", 1)))
	var expected_loss := mini(total_after_upgrade, maxi(1, int(round(float(total_after_upgrade) / float(max_hp)))))
	_monster_controller(main).call("_auto_monster_take_damage", 0, 1, "烟测升级后受伤", -1)
	var after_damage_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_damage_monsters := _as_array(main.get("auto_monsters"))
	var damaged_actor := after_damage_monsters[0] as Dictionary
	var damage_ok := int((after_damage_players[owner] as Dictionary).get("cash", 0)) == cash_before_damage - expected_loss \
		and bool(damaged_actor.get("owner_revealed", false)) \
		and String(damaged_actor.get("owner_clue", "")).contains("烟测升级后受伤") \
		and int(damaged_actor.get("owner_damage_cash_lost", 0)) == expected_loss \
		and int(damaged_actor.get("owner_damage_cash_pool", -1)) == total_after_upgrade - expected_loss \
		and int(damaged_actor.get("last_owner_damage_cash_loss", 0)) == expected_loss \
		and int(damaged_actor.get("last_owner_damage_amount", 0)) == 1
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	main.set("auto_monsters", previous_monsters)
	_replace_public_log_messages(main, previous_logs)
	_set_visual_cue_array(main, "action_callouts", previous_callouts)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
	main.call("_refresh_ui")
	return upgrade_ok and damage_ok


func _verify_single_owned_monster_limit_and_rank_iv_refresh(main: Node) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var previous_logs := _public_log_messages(main).duplicate(true)
	var previous_callouts := _visual_cue_array(main, "action_callouts").duplicate(true)
	var previous_selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	var previous_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if previous_players.is_empty() or previous_monsters.is_empty() or districts.is_empty():
		return false
	var owner := 0
	var owned_slot := -1
	for i in range(previous_monsters.size()):
		var actor := previous_monsters[i] as Dictionary
		if int(actor.get("owner", -1)) == owner and not bool(actor.get("down", false)):
			owned_slot = i
			break
	if owned_slot < 0:
		return false
	var monsters := previous_monsters.duplicate(true)
	var actor := (monsters[owned_slot] as Dictionary).duplicate(true)
	var catalog_index := int(actor.get("catalog_index", 0))
	var other_catalog_index := (catalog_index + 1) % int(main.call("_catalog_size"))
	var district_index := clampi(int(actor.get("position", previous_selected_district)), 0, districts.size() - 1)
	main.set("auto_monsters", monsters)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = owner
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var other_card := main.call("_make_skill", main.call("_monster_card_name", other_catalog_index, 1)) as Dictionary
	other_card["starter_play_free"] = true
	other_card["summon_access"] = "any"
	var rejected_new_monster := not bool(_monster_controller(main).call("_summon_monster_from_card", previous_players[owner] as Dictionary, other_card))
	var after_reject := _as_array(main.get("auto_monsters"))
	var cap_ok := rejected_new_monster and after_reject.size() == previous_monsters.size()
	monsters = after_reject.duplicate(true)
	actor = (monsters[owned_slot] as Dictionary).duplicate(true)
	actor["rank"] = 4
	actor["hp"] = 1
	actor["remaining_time"] = 0.25
	actor["owner_revealed"] = false
	actor["owner_clue"] = ""
	monsters[owned_slot] = actor
	main.set("auto_monsters", monsters)
	var same_card := main.call("_make_skill", main.call("_monster_card_name", catalog_index, 1)) as Dictionary
	same_card["starter_play_free"] = true
	same_card["summon_access"] = "any"
	var rank_four_card := main.call("_make_skill", main.call("_monster_card_name", catalog_index, 4)) as Dictionary
	var refreshed := bool(_monster_controller(main).call("_summon_monster_from_card", previous_players[owner] as Dictionary, same_card))
	var after_refresh := _as_array(main.get("auto_monsters"))
	var refreshed_actor := after_refresh[owned_slot] as Dictionary
	var refresh_ok := refreshed \
		and after_refresh.size() == previous_monsters.size() \
		and int(refreshed_actor.get("rank", 0)) == 4 \
		and int(refreshed_actor.get("hp", 0)) == int(rank_four_card.get("hp", -1)) \
		and int(refreshed_actor.get("max_hp", 0)) == int(rank_four_card.get("hp", -2)) \
		and is_equal_approx(float(refreshed_actor.get("remaining_time", 0.0)), float(rank_four_card.get("duration", -1.0))) \
		and is_equal_approx(float(refreshed_actor.get("duration", 0.0)), float(rank_four_card.get("duration", -2.0)))
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	main.set("auto_monsters", previous_monsters)
	_replace_public_log_messages(main, previous_logs)
	_set_visual_cue_array(main, "action_callouts", previous_callouts)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
	main.call("_refresh_ui")
	return cap_ok and refresh_ok


func _verify_monster_takeover_resets_owner_clues(main: Node) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	if previous_players.size() < 2 or previous_monsters.is_empty():
		return false
	var players := previous_players.duplicate(true)
	var monsters := previous_monsters.duplicate(true)
	var actor := monsters[0] as Dictionary
	var monster_uid := int(actor.get("uid", 0))
	if monster_uid <= 0:
		return false
	var old_owner := 0
	var new_owner := 1
	for i in range(monsters.size()):
		if i == 0:
			continue
		var other_actor := monsters[i] as Dictionary
		if int(other_actor.get("owner", -1)) == new_owner:
			other_actor["owner"] = -1
			monsters[i] = other_actor
	var old_owner_active_before := _active_bound_skill_count_for_uid(players, old_owner, monster_uid)
	if old_owner_active_before <= 0:
		return false
	var old_player := players[old_owner] as Dictionary
	old_player["cash"] = 5000
	players[old_owner] = old_player
	var new_player := players[new_owner] as Dictionary
	new_player["cash"] = 5000
	new_player["economic_ledger"] = []
	new_player["cash_history"] = [5000]
	players[new_owner] = new_player
	actor["owner"] = old_owner
	actor["owner_revealed"] = true
	actor["owner_clue"] = "烟测旧归属线索"
	actor["down"] = false
	actor["armor"] = 0
	actor["hp"] = 100
	actor["max_hp"] = 100
	actor["owner_damage_cash_total"] = 1000
	actor["owner_damage_cash_lost"] = 400
	actor["owner_damage_cash_pool"] = 600
	monsters[0] = actor
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	main.set("auto_monsters", monsters)
	var new_owner_active_before := _active_bound_skill_count_for_uid(players, new_owner, monster_uid)
	var takeover_skill := main.call("_make_skill", "夺取怪兽1") as Dictionary
	if not bool(_monster_controller(main).call("_apply_monster_takeover", takeover_skill, 0, new_owner)):
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
		main.set("auto_monsters", previous_monsters)
		return false
	var after_takeover_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_takeover_monsters := _as_array(main.get("auto_monsters"))
	var taken_actor := after_takeover_monsters[0] as Dictionary
	var takeover_ok := int(taken_actor.get("owner", -1)) == new_owner \
		and not bool(taken_actor.get("owner_revealed", true)) \
		and String(taken_actor.get("owner_clue", "")).contains("等待下一次受伤资金线索") \
		and int(taken_actor.get("owner_damage_cash_lost", -1)) == 0 \
		and int(taken_actor.get("owner_damage_cash_pool", -1)) == int(taken_actor.get("owner_damage_cash_total", -2)) \
		and _active_bound_skill_count_for_uid(after_takeover_players, old_owner, monster_uid) == 0 \
		and _active_bound_skill_count_for_uid(after_takeover_players, new_owner, monster_uid) > new_owner_active_before
	var new_cash_before := int((after_takeover_players[new_owner] as Dictionary).get("cash", 0))
	_monster_controller(main).call("_auto_monster_take_damage", 0, 10, "烟测夺取后受伤", -1)
	var after_damage_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_damage_monsters := _as_array(main.get("auto_monsters"))
	var damaged_actor := after_damage_monsters[0] as Dictionary
	var after_damage_new_player := after_damage_players[new_owner] as Dictionary
	var damage_ok := int(after_damage_new_player.get("cash", 0)) == new_cash_before - 100 \
		and bool(damaged_actor.get("owner_revealed", false)) \
		and String(damaged_actor.get("owner_clue", "")).contains(String(after_damage_new_player.get("name", "玩家2"))) \
		and int(damaged_actor.get("owner_damage_cash_lost", 0)) == 100
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	main.set("auto_monsters", previous_monsters)
	return takeover_ok and damage_ok


func _verify_reacquired_card_upgrade_rules(main: Node) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if districts.is_empty():
		return false
	var district_index := 0
	var player := {
		"name": "烟测升级者",
		"slots": [main.call("_make_skill", "移动1")],
	}
	if not bool(main.call("_acquire_card_for_player", player, "移动1", district_index, "烟测区域")):
		return false
	var names := _player_card_names([player], 0)
	var upgraded_to_rank_ii := names.size() == 1 and names.has("移动2") and not names.has("移动1")
	var base_price := int(main.call("_card_price", "移动1"))
	var rank_iv_price := int(main.call("_card_price", "移动4"))
	var max_player := {
		"name": "烟测上限者",
		"slots": [main.call("_make_skill", "移动4")],
	}
	var rejected_at_cap := not bool(main.call("_acquire_card_for_player", max_player, "移动1", district_index, "烟测区域"))
	var max_names := _player_card_names([max_player], 0)
	return upgraded_to_rank_ii \
		and base_price == rank_iv_price \
		and rejected_at_cap \
		and max_names.size() == 1 \
		and max_names.has("移动4")


func _roman_level(rank: int) -> String:
	match clampi(rank, 1, 4):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
	return "I"


func _card_rank_power_score(main: Node, skill_name: String) -> float:
	var skill := main.call("_make_skill", skill_name) as Dictionary
	if skill.is_empty():
		return -1.0
	var score := float(maxi(0, int(skill.get("cost", 0)))) * 10.0
	for key in [
		"damage", "armor", "guard", "ranged_guard", "panic", "revenue_amount", "cash",
		"draw_amount", "repair_routes", "route_damage", "contract_income",
		"market_demand_pressure", "market_supply_pressure", "miasma_count", "reclaim_count",
		"product_level", "product_shift", "demand_shift", "contract_add_products", "contract_add_demands",
		"contract_remove_products", "contract_remove_demands", "accept_cash", "decline_cash_penalty",
		"decline_route_damage", "stabilize_amount", "hp", "fixed_skill_count"
	]:
		score += float(abs(int(skill.get(key, 0)))) * 12.0
	for key in [
		"price_delta", "volatility_delta", "production_delta", "transport_delta", "consumption_delta",
		"accept_production_delta", "accept_transport_delta", "accept_consumption_delta",
		"decline_production_delta", "decline_transport_delta", "decline_consumption_delta"
	]:
		score += float(abs(int(skill.get(key, 0)))) * 14.0
	for key in ["move", "range", "knockback", "delay", "lure_speedup", "duration"]:
		score += absf(float(skill.get(key, 0.0))) * 0.04
	for key in ["growth_multiplier", "route_flow_multiplier", "accept_route_flow_multiplier"]:
		score += absf(float(skill.get(key, 1.0)) - 1.0) * 120.0
	var derivative_terms: Dictionary = skill.get("gdp_derivative_terms", {}) as Dictionary if skill.get("gdp_derivative_terms", {}) is Dictionary else {}
	score += absf(float(derivative_terms.get("multiplier", 0.0))) * 80.0
	score += maxf(0.0, float(derivative_terms.get("duration_seconds", 0.0))) * 0.5
	for key in ["contract_turns", "market_contract_turns", "growth_turns", "route_flow_turns"]:
		score += float(maxi(0, int(skill.get(key, 0)))) * 4.0
	return score


func _verify_card_rank_ladders_are_complete(main: Node) -> bool:
	var names := _as_array(main.call("_card_codex_names", "all"))
	var checked := 0
	for name_variant in names:
		var base_name := String(name_variant)
		if base_name == "":
			continue
		var family := _skill_family(base_name)
		var base_price := int(main.call("_card_price", "%s1" % family))
		var previous_score := -1.0
		var previous_budget := -1
		for rank in range(1, 5):
			var ranked_name := "%s%d" % [family, rank]
			if not _runtime_card_exists(main, ranked_name):
				print("Missing rank %d for %s" % [rank, family])
				return false
			if int(main.call("_card_price", ranked_name)) != base_price:
				print("Rank price drift for %s" % ranked_name)
				return false
			var display := String(main.call("_card_display_name", ranked_name))
			if not display.contains("%s级" % _roman_level(rank)):
				print("Roman rank label missing for %s: %s" % [ranked_name, display])
				return false
			var score := _card_rank_power_score(main, ranked_name)
			if score < 0.0:
				print("Rank has empty skill definition: %s" % ranked_name)
				return false
			if previous_score >= 0.0 and score + 0.001 < previous_score:
				print("Rank power regressed for %s: %.2f < %.2f" % [ranked_name, score, previous_score])
				return false
			previous_score = score
			var budget_points := _diagnostics(main).card_budget_points_for_id(ranked_name)
			if budget_points <= 0:
				print("Rank has empty strength budget: %s" % ranked_name)
				return false
			if previous_budget >= 0 and budget_points < previous_budget:
				print("Rank strength budget regressed for %s: %d < %d" % [ranked_name, budget_points, previous_budget])
				return false
			previous_budget = budget_points
		checked += 1
	return checked >= 40


func _v06_facility_owner_chain_snapshot() -> Dictionary:
	var result := {
		"market_ready": false,
		"purchase_committed": false,
		"slot_index": -1,
		"cash_spent": false,
		"play_finalized": false,
		"source_finalized": false,
	}
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return result
	var fixture := packed.instantiate()
	var fixture_save_path := "user://test_runs/smoke_v06_facility_owner_fixture.save"
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	var save_coordinator := fixture.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", fixture_save_path))
	if not save_override_ready:
		fixture.free()
		return result
	fixture.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	fixture.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	fixture.set("configured_role_indices", [0, 1, 2, 3, 4])
	fixture.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	get_root().add_child(fixture)
	fixture.call("_new_game")
	fixture.set_process(false)
	var coordinator := _runtime_card_coordinator(fixture)
	if coordinator != null and coordinator.has_method("refresh_v06_production_player_bindings"):
		coordinator.call("refresh_v06_production_player_bindings", fixture)
	var actor_binding: Dictionary = coordinator.call("actor_id_for_player_index", 0) if coordinator != null and coordinator.has_method("actor_id_for_player_index") else {}
	var actor_id := String(actor_binding.get("actor_id", "")).strip_edges()
	var facility_card: Dictionary = coordinator.call("v06_facility_card") if coordinator != null and coordinator.has_method("v06_facility_card") else {}
	var facility_machine: Dictionary = facility_card.get("machine", {}) if facility_card.get("machine", {}) is Dictionary else {}
	var facility_card_id := String(facility_machine.get("card_id", ""))
	var market: Dictionary = coordinator.call("v06_facility_market_snapshot", actor_id) if coordinator != null and coordinator.has_method("v06_facility_market_snapshot") and bool(actor_binding.get("available", false)) else {}
	var listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
	var player_before: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id) if coordinator != null and coordinator.has_method("v06_card_player_snapshot") else {}
	var purchase: Dictionary = coordinator.call(
		"purchase_v06_facility_card",
		actor_id,
		String(listing.get("item_id", "")),
		"smoke:v06-facility-purchase:%s" % actor_id,
	) if bool(market.get("ready", false)) and facility_card_id != "" else {}
	var player_after: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id) if coordinator != null and coordinator.has_method("v06_card_player_snapshot") else {}
	var inventory: Dictionary = player_after.get("inventory", {}) if player_after.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var slot_index := -1
	for candidate_index in range(slots.size()):
		if not (slots[candidate_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[candidate_index] as Dictionary).get("machine", {}) if (slots[candidate_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if String(machine.get("card_id", "")) == facility_card_id:
			slot_index = candidate_index
			break
	var target_district := _first_buildable_land_district(_as_array(fixture.get("districts")))
	var target_region_id := ""
	if target_district >= 0:
		var target_entry := _as_array(fixture.get("districts"))[target_district] as Dictionary
		target_region_id = String(target_entry.get("region_id", "")).strip_edges()
	var play: Dictionary = coordinator.call("play_v06_runtime_card", {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": "smoke:v06-facility-play:%s" % actor_id,
		"region_id": target_region_id,
		"game_time": float(fixture.get("game_time")),
	}) if bool(purchase.get("committed", false)) and slot_index >= 0 and target_region_id != "" else {}
	var finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	var owner_result: Dictionary = finalization.get("owner_result", {}) if finalization.get("owner_result", {}) is Dictionary else {}
	var nested_owner_result: Dictionary = owner_result.get("owner_result", {}) if owner_result.get("owner_result", {}) is Dictionary else {}
	var facility_result: Dictionary = nested_owner_result.get("facility_result", {}) if nested_owner_result.get("facility_result", {}) is Dictionary else {}
	var commodity_result: Dictionary = nested_owner_result.get("commodity_result", {}) if nested_owner_result.get("commodity_result", {}) is Dictionary else {}
	result["market_ready"] = bool(market.get("ready", false)) and facility_card_id != ""
	result["purchase_committed"] = bool(purchase.get("committed", false))
	result["slot_index"] = slot_index
	result["cash_spent"] = int(player_after.get("cash", -1)) < int(player_before.get("cash", -1))
	result["play_finalized"] = bool(play.get("committed", false)) and bool(finalization.get("finalized", false))
	result["source_finalized"] = bool(facility_result.get("finalized", false)) and bool(commodity_result.get("finalized", false))
	fixture.queue_free()
	await process_frame
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	return result


func _verify_ten_hour_route_pack(_main: Node) -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var main := packed.instantiate()
	var fixture_save_path := "user://test_runs/smoke_ten_hour_route_pack_fixture.save"
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", fixture_save_path))
	if not save_override_ready:
		main.free()
		return false
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	get_root().add_child(main)
	main.call("_new_game")
	main.set("opening_guide_dismissed", true)
	var ok := true
	var failures := []
	var families := ["应急修复", "竞争封锁", "线索悬赏", "航线预报"]
	for family_variant in families:
		var family := String(family_variant)
		var base_price := int(main.call("_card_price", "%s1" % family))
		var previous_budget := -1
		for rank in range(1, 5):
			var card_name := "%s%d" % [family, rank]
			if not _runtime_card_exists(main, card_name):
				failures.append("missing %s" % card_name)
				ok = false
				continue
			if int(main.call("_card_price", card_name)) != base_price:
				failures.append("price drift %s" % card_name)
				ok = false
			var display := String(main.call("_card_display_name", card_name))
			if not display.contains("%s级" % _roman_level(rank)):
				failures.append("roman label %s -> %s" % [card_name, display])
				ok = false
			var budget := _diagnostics(main).card_budget_points_for_id(card_name)
			if previous_budget >= 0 and budget < previous_budget:
				failures.append("budget regression %s" % card_name)
				ok = false
			previous_budget = budget
	var run_pool := _as_array(main.call("_current_run_card_pool"))
	for family_variant in families:
		var base_name := "%s1" % String(family_variant)
		if bool(main.call("_card_allowed_by_run_products", base_name)) and not run_pool.has(base_name):
			failures.append("not in run pool %s" % base_name)
			ok = false
		for rank in range(2, 5):
			if run_pool.has("%s%d" % [String(family_variant), rank]):
				failures.append("non-base in run pool %s%d" % [String(family_variant), rank])
				ok = false
	var route_expectations := {
		"应急修复1": {"route": "城市成长", "pillars": ["收益", "防御"]},
		"竞争封锁1": {"route": "城市压制", "pillars": ["压制"]},
		"线索悬赏1": {"route": "情报推理", "pillars": ["信息"]},
		"航线预报1": {"route": "天气博弈", "pillars": ["公开门槛"]},
	}
	for card_variant in route_expectations.keys():
		var card_name := String(card_variant)
		var skill := main.call("_make_skill", card_name) as Dictionary
		var expected := route_expectations[card_name] as Dictionary
		var route_label := _card_presentation_text(main, skill, "strategy_route_label", card_name)
		if route_label != String(expected.get("route", "")):
			failures.append("route %s -> %s" % [card_name, route_label])
			ok = false
		var pillars := _as_array(_diagnostics(main).card_balance_pillars(skill, {
			"card_id": card_name,
			"strategy_route_label": route_label,
		}))
		for pillar_variant in _as_array(expected.get("pillars", [])):
			var pillar := String(pillar_variant)
			if not pillars.has(pillar):
				failures.append("pillar %s lacks %s -> %s" % [card_name, pillar, str(pillars)])
				ok = false
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var repair_district := _first_buildable_land_district(districts)
	if repair_district < 0:
		failures.append("no repair district")
		ok = false
	else:
		ok = ok and CITY_FIXTURES.create_city_bool(main, 0, repair_district, "十小时修复烟测城")
		ok = ok and _set_city_goods_for_test(main, repair_district, "光合凝胶", "轨迹墨水")
		var districts_after_city := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		var repair_entry := districts_after_city[repair_district] as Dictionary
		var city := (repair_entry.get("city", {}) as Dictionary).duplicate(true)
		city["trade_route_damage"] = 3
		var repair_skill := main.call("_make_skill", "应急修复3") as Dictionary
		var route_formula := _runtime_coordinator(main).get_node_or_null("CardEconomyProductRouteFormulaRuntimeService")
		var repair_result: Dictionary = route_formula.call("calculate", "route_insurance", {
			"city": city,
			"repair_routes": int(repair_skill.get("repair_routes", 0)),
			"revenue_amount": int(repair_skill.get("revenue_amount", 0)),
			"route_flow_multiplier": float(repair_skill.get("route_flow_multiplier", 1.0)),
			"route_flow_seconds": float(repair_skill.get("route_flow_seconds", 0.0)),
			"source": "smoke_ten_hour_route_pack",
		}) if route_formula != null and route_formula.has_method("calculate") else {}
		var repaired_city := repair_result.get("city", {}) as Dictionary
		if not bool(repair_result.get("changed", false)) or int(repaired_city.get("trade_route_damage", 99)) > 0 or float(repaired_city.get("route_flow_multiplier", 1.0)) < 1.39:
			failures.append("repair resolver damage=%d flow=%.2f" % [
				int(repaired_city.get("trade_route_damage", 99)),
				float(repaired_city.get("route_flow_multiplier", 1.0)),
			])
			ok = false
	var ai_ok := true
	var ai_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var own_index := _first_buildable_land_district(ai_districts)
	if own_index >= 0:
		ai_ok = ai_ok and CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI修复路线烟测城")
		ai_ok = ai_ok and _set_city_goods_for_test(main, own_index, "光合凝胶", "轨迹墨水")
	var weather_index := _first_buildable_land_district(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts))
	if weather_index >= 0:
		ai_ok = ai_ok and CITY_FIXTURES.create_city_bool(main, 1, weather_index, "AI航线预报烟测城")
		ai_ok = ai_ok and _set_city_goods_for_test(main, weather_index, "离岸水晶", "轨迹墨水")
	var rival_index := _first_buildable_land_district(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts))
	if rival_index >= 0:
		ai_ok = ai_ok and CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI封锁路线烟测城")
		ai_ok = ai_ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料")
	if ai_ok and own_index >= 0 and rival_index >= 0:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		if players.size() > 2:
			var rival_player := players[2] as Dictionary
			rival_player["cash"] = 9000
			players[2] = rival_player
		var ai_player := players[1] as Dictionary
		ai_player["cash"] = 8000
		ai_player["action_cooldown"] = 0.0
		ai_player["slots"] = [
			main.call("_make_skill", "应急修复1"),
			main.call("_make_skill", "竞争封锁1"),
			main.call("_make_skill", "线索悬赏1"),
			main.call("_make_skill", "航线预报1"),
		]
		players[1] = ai_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var ai_contexts := []
		for slot_index in range(4):
			var ctx := _ai_controller(main).call("_ai_card_play_context", 1, slot_index, (ai_player["slots"][slot_index] as Dictionary)) as Dictionary
			ai_contexts.append(ctx)
		if (ai_contexts[0] as Dictionary).is_empty() or String((ai_contexts[0] as Dictionary).get("reason", "")).find("保护") < 0:
			failures.append("AI repair context missing")
			ok = false
		if (ai_contexts[1] as Dictionary).is_empty() or int((ai_contexts[1] as Dictionary).get("target_owner", -1)) != 2:
			failures.append("AI lockdown target owner")
			ok = false
		if (ai_contexts[3] as Dictionary).is_empty() or String((ai_contexts[3] as Dictionary).get("reason", "")).find("天气") < 0:
			failures.append("AI weather context missing")
			ok = false
	else:
		failures.append("AI route setup")
		ok = false
	if not failures.is_empty():
		print("Ten-hour route pack failures: %s" % " / ".join(failures))
	main.free()
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	return ok


func _verify_direct_player_interaction_cards(_main: Node) -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var main := packed.instantiate()
	var fixture_save_path := "user://test_runs/smoke_direct_player_interaction_fixture.save"
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", fixture_save_path))
	if not save_override_ready:
		main.free()
		return false
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	get_root().add_child(main)
	main.call("_new_game")
	var ok := true
	var failures := []
	var families := {
		"星链拆解": "player_hand_disrupt",
		"影仓牵引": "player_hand_steal",
		"产权冻结": "city_control_dispute",
		"轨道齐射": "global_barrage",
	}
	var interaction_names := _as_array(main.call("_card_codex_names", "interaction"))
	var run_pool := _as_array(main.call("_current_run_card_pool"))
	for family_variant in families.keys():
		var family := String(family_variant)
		var expected_kind := String(families[family])
		var base_price := int(main.call("_card_price", "%s1" % family))
		var previous_budget := -1
		for rank in range(1, 5):
			var card_name := "%s%d" % [family, rank]
			if not _runtime_card_exists(main, card_name):
				failures.append("missing %s" % card_name)
				ok = false
				continue
			var skill := main.call("_make_skill", card_name) as Dictionary
			var coordinator := _runtime_card_coordinator(main)
			var presentation_variant: Variant = coordinator.call("compose_card_presentation", {
				"card_name": card_name,
				"skill": skill,
				"rank": rank,
			}) if coordinator != null else {}
			var presentation: Dictionary = presentation_variant if presentation_variant is Dictionary else {}
			if String(skill.get("kind", "")) != expected_kind:
				failures.append("kind %s -> %s" % [card_name, String(skill.get("kind", ""))])
				ok = false
			if int(main.call("_card_price", card_name)) != base_price:
				failures.append("price drift %s" % card_name)
				ok = false
			if not String(main.call("_card_display_name", card_name)).contains("%s级" % _roman_level(rank)):
				failures.append("roman label missing %s" % card_name)
				ok = false
			if String(presentation.get("strategy_route_label", "")) != "直接互动":
				failures.append("route %s" % card_name)
				ok = false
			if String(presentation.get("category_id", "")) != "interaction":
				failures.append("category %s" % card_name)
				ok = false
			var budget := _diagnostics(main).card_budget_points_for_id(card_name)
			if budget <= 0 or (previous_budget >= 0 and budget < previous_budget):
				failures.append("budget regression %s" % card_name)
				ok = false
			previous_budget = budget
		var base_name := "%s1" % family
		if bool(main.call("_card_allowed_by_run_products", base_name)):
			if not interaction_names.has(base_name):
				failures.append("interaction codex lacks %s" % base_name)
				ok = false
			if not run_pool.has(base_name):
				failures.append("run pool lacks %s" % base_name)
				ok = false
	for family_variant in families.keys():
		var family := String(family_variant)
		for rank in range(2, 5):
			if run_pool.has("%s%d" % [family, rank]):
				failures.append("run pool exposes upgraded %s%d" % [family, rank])
				ok = false
	var disrupt := main.call("_make_skill", "星链拆解1") as Dictionary
	var steal := main.call("_make_skill", "影仓牵引1") as Dictionary
	var freeze := main.call("_make_skill", "产权冻结1") as Dictionary
	var barrage := main.call("_make_skill", "轨道齐射1") as Dictionary
	ok = ok and bool((main.call("_card_play_target_snapshot", disrupt) as Dictionary).get("requires_target_player", false))
	ok = ok and bool((main.call("_card_play_target_snapshot", steal) as Dictionary).get("requires_target_player", false))
	ok = ok and not bool((main.call("_card_play_target_snapshot", freeze) as Dictionary).get("requires_target_player", false))
	ok = ok and not bool((main.call("_card_play_target_snapshot", barrage) as Dictionary).get("requires_target_player", false))
	ok = ok and str(_card_presentation_array(main, disrupt, "key_rule_facts")).contains("拆牌")
	ok = ok and str(_card_presentation_array(main, steal, "key_rule_facts")).contains("牵牌")
	ok = ok and str(_card_presentation_array(main, freeze, "key_rule_facts")).contains("产权冻结")
	ok = ok and str(_card_presentation_array(main, barrage, "key_rule_facts")).contains("齐射")
	if _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size() >= 2:
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = maxi(0, int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district))
		_set_player_skill(main, 1, 2, "城市融资1")
		_set_player_skill(main, 1, 3, "价格套利1")
		var target_hand_before := _player_card_names(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 1).size()
		ok = ok and bool(main.call("_apply_player_hand_disrupt", 0, 1, disrupt))
		var target_hand_after := _player_card_names(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 1).size()
		ok = ok and target_hand_after < target_hand_before
		_set_player_skill(main, 1, 2, "城市融资1")
		var actor_hand_before := _player_card_names(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0).size()
		ok = ok and bool(main.call("_apply_player_hand_steal", 0, 1, steal))
		var actor_hand_after := _player_card_names(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0).size()
		ok = ok and actor_hand_after >= actor_hand_before
		_set_player_skill(main, 0, 2, "星链拆解1")
		# Target-selection UI is independent from the GDP qualification gate;
		# the authoritative gate is covered by card_play_requirement_policy_test.
		var ui_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		var ui_player := ui_players[0] as Dictionary
		var ui_slots := _as_array(ui_player.get("slots", [])).duplicate(true)
		var ui_disrupt := (ui_slots[2] as Dictionary).duplicate(true)
		ui_disrupt["play_requirement_kind"] = "none"
		ui_disrupt["play_region_gdp_share_required"] = 0
		ui_slots[2] = ui_disrupt
		ui_player["slots"] = ui_slots
		ui_players[0] = ui_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = ui_players
		_clear_player_cooldown(main, 0)
		main.call("_use_skill", 2)
		ok = ok and bool(main.call("_has_pending_player_target_choice"))
		main.call("_cancel_pending_player_target_choice")
	if _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size() >= 3:
		var setup_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		for i in range(setup_players.size()):
			var setup_player := setup_players[i] as Dictionary
			setup_player["cash"] = 5000 + i * 1200
			if i == 0:
				setup_player["is_ai"] = true
				setup_player["seat_type"] = "ai"
			setup_players[i] = setup_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = setup_players
		var ai_setup_indices := []
		var setup_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		for i in range(setup_districts.size()):
			var setup_district := setup_districts[i] as Dictionary
			if String(setup_district.get("terrain", "")) == "land" and not bool(setup_district.get("destroyed", false)) and ((setup_district.get("city", {}) as Dictionary).is_empty()):
				ai_setup_indices.append(i)
				if ai_setup_indices.size() >= 3:
					break
		if ai_setup_indices.size() >= 3:
			var own_ai_city := int(ai_setup_indices[0])
			var rival_ai_city := int(ai_setup_indices[1])
			var leader_ai_city := int(ai_setup_indices[2])
			CITY_FIXTURES.create_city_bool(main, 0, own_ai_city, "直接互动AI自城")
			CITY_FIXTURES.create_city_bool(main, 1, rival_ai_city, "直接互动AI竞城")
			CITY_FIXTURES.create_city_bool(main, 2, leader_ai_city, "直接互动AI领跑城")
			setup_districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
			var own_city := ((setup_districts[own_ai_city] as Dictionary).get("city", {}) as Dictionary)
			own_city["products"] = [{"name": "轨迹墨水", "level": 4}]
			own_city["demands"] = ["活体芯片"]
			own_city["last_income"] = 360
			var own_ai_district := setup_districts[own_ai_city] as Dictionary
			own_ai_district["city"] = own_city
			setup_districts[own_ai_city] = own_ai_district
			var rival_city := ((setup_districts[rival_ai_city] as Dictionary).get("city", {}) as Dictionary)
			rival_city["products"] = [{"name": "活体芯片", "level": 2}]
			rival_city["demands"] = ["轨迹墨水"]
			rival_city["last_income"] = 460
			var rival_ai_district := setup_districts[rival_ai_city] as Dictionary
			rival_ai_district["city"] = rival_city
			setup_districts[rival_ai_city] = rival_ai_district
			var leader_city := ((setup_districts[leader_ai_city] as Dictionary).get("city", {}) as Dictionary)
			leader_city["products"] = [{"name": "轨迹墨水", "level": 3}, {"name": "活体芯片", "level": 2}]
			leader_city["demands"] = ["星鳍鱼群", "巨藻纤维"]
			leader_city["last_income"] = 1400
			leader_city["warehouse_stockpile_count"] = 2
			leader_city["warehouse_stockpile_units"] = 5
			leader_city["warehouse_stockpile_products"] = ["轨迹墨水"]
			leader_city["trade_routes"] = [{"product": "轨迹墨水", "path": [leader_ai_city], "flow_amount": 2.0, "flow_speed": 1.0}]
			var leader_ai_district := setup_districts[leader_ai_city] as Dictionary
			leader_ai_district["city"] = leader_city
			setup_districts[leader_ai_city] = leader_ai_district
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = setup_districts
			var rich_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
			(rich_players[0] as Dictionary)["cash"] = 5200
			(rich_players[1] as Dictionary)["cash"] = 6100
			(rich_players[2] as Dictionary)["cash"] = 12000
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = rich_players
			var ai_disrupt := disrupt.duplicate(true)
			ai_disrupt["play_requirement_kind"] = "none"
			ai_disrupt["play_region_gdp_share_required"] = 0
			var ai_freeze := freeze.duplicate(true)
			ai_freeze["play_requirement_kind"] = "none"
			ai_freeze["play_region_gdp_share_required"] = 0
			var ai_barrage := barrage.duplicate(true)
			ai_barrage["play_requirement_kind"] = "none"
			ai_barrage["play_region_gdp_share_required"] = 0
			var disrupt_context := _ai_controller(main).call("_ai_card_play_context", 0, 2, ai_disrupt) as Dictionary
			if disrupt_context.is_empty() or int(disrupt_context.get("target_player", -1)) != 2:
				failures.append("AI direct player target plan")
				ok = false
			if String(disrupt_context.get("direct_interaction_role", "")).find("leader") < 0 or int(disrupt_context.get("direct_effect_pressure", 0)) <= 0:
				failures.append("AI direct player metadata")
				ok = false
			var direct_training := _ai_controller(main).call("_ai_candidate_training_view", disrupt_context) as Dictionary
			if not direct_training.has("direct_interaction_role") or not direct_training.has("direct_target_public_card_signal"):
				failures.append("AI direct training view")
				ok = false
			var freeze_context := _ai_controller(main).call("_ai_card_play_context", 0, 2, ai_freeze) as Dictionary
			if freeze_context.is_empty() or int(freeze_context.get("target_city", -1)) != leader_ai_city:
				failures.append("AI control dispute target plan")
				ok = false
			if int(freeze_context.get("direct_city_warehouse_pressure", 0)) <= 0 or String(freeze_context.get("direct_interaction_role", "")).find("leader") < 0:
				failures.append("AI control dispute metadata")
				ok = false
			var barrage_context := _ai_controller(main).call("_ai_card_play_context", 0, 2, ai_barrage) as Dictionary
			if barrage_context.is_empty() or int(barrage_context.get("target_city", -1)) != leader_ai_city:
				failures.append("AI barrage target plan")
				ok = false
			if int(barrage_context.get("direct_barrage_expected_damage", 0)) <= 0 or int(barrage_context.get("direct_city_warehouse_pressure", 0)) <= 0:
				failures.append("AI barrage metadata")
				ok = false
		else:
			failures.append("AI direct interaction setup lacks land districts")
			ok = false
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var freeze_target := -1
	for i in range(districts.size()):
		var district := districts[i] as Dictionary
		if String(district.get("terrain", "")) == "land" and not bool(district.get("destroyed", false)) and ((district.get("city", {}) as Dictionary).is_empty()):
			freeze_target = i
			break
	if freeze_target >= 0:
		CITY_FIXTURES.create_city_bool(main, 1, freeze_target, "互动烟测城")
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = freeze_target
		ok = ok and bool(main.call("_apply_city_control_dispute", 0, freeze))
		districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		var city := ((districts[freeze_target] as Dictionary).get("city", {}) as Dictionary)
		ok = ok and float(city.get("control_dispute_until", 0.0)) > float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time)
		var damage_before := 0
		for damage_district_variant in districts:
			var damage_district := damage_district_variant as Dictionary
			damage_before += int(damage_district.get("damage", 0))
		ok = ok and bool(main.call("_apply_global_barrage", 0, barrage))
		districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		var damage_after := 0
		for damage_district_after_variant in districts:
			var damage_district_after := damage_district_after_variant as Dictionary
			damage_after += int(damage_district_after.get("damage", 0))
		ok = ok and damage_after > damage_before
	if not failures.is_empty():
		print("Direct interaction card failures: %s" % " / ".join(failures))
		ok = false
	main.free()
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	return ok


func _verify_direct_interaction_balance_audit(main: Node) -> bool:
	var report := _diagnostics(main).direct_interaction_balance_report()
	var families := report.get("families", {}) as Dictionary
	var entries := _as_array(report.get("entries", []))
	var issues := _as_array(report.get("issues", []))
	if not bool(report.get("ok", false)):
		print("Direct interaction balance audit issues: %s" % " / ".join(issues))
		return false
	var required := {
		"星链拆解": "player_hand_disrupt",
		"影仓牵引": "player_hand_steal",
		"产权冻结": "city_control_dispute",
		"轨道齐射": "global_barrage",
	}
	var ok := true
	for family_variant in required.keys():
		var family := String(family_variant)
		if not families.has(family):
			ok = false
			continue
		var summary := families[family] as Dictionary
		ok = ok and String(summary.get("kind", "")) == String(required[family])
		ok = ok and _as_array(summary.get("cards", [])).size() == 4
		ok = ok and int(summary.get("max_share_required", 0)) >= 40
		ok = ok and int(summary.get("max_gate_score", 0)) >= 180
		ok = ok and int(summary.get("max_public_clue_score", 0)) >= 80
		ok = ok and bool(summary.get("counter_available", false))
	var by_name := {}
	for entry_variant in entries:
		if entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			by_name[String(entry.get("name", ""))] = entry
	for card_name in ["星链拆解4", "影仓牵引4", "产权冻结4", "轨道齐射4"]:
		if not by_name.has(card_name):
			ok = false
			continue
		var entry := by_name[card_name] as Dictionary
		ok = ok and int(entry.get("effect_score", 0)) >= 150
		ok = ok and int(entry.get("gate_score", 0)) >= 120
		ok = ok and int(entry.get("public_clue_score", 0)) >= 78
		ok = ok and int(entry.get("required_share_percent", 0)) >= 10
		ok = ok and bool(entry.get("counter_available", false))
	var disrupt_one := by_name.get("星链拆解1", {}) as Dictionary
	var disrupt_four := by_name.get("星链拆解4", {}) as Dictionary
	var steal_one := by_name.get("影仓牵引1", {}) as Dictionary
	var steal_four := by_name.get("影仓牵引4", {}) as Dictionary
	var freeze_one := by_name.get("产权冻结1", {}) as Dictionary
	var freeze_four := by_name.get("产权冻结4", {}) as Dictionary
	var barrage_one := by_name.get("轨道齐射1", {}) as Dictionary
	var barrage_four := by_name.get("轨道齐射4", {}) as Dictionary
	ok = ok and not disrupt_one.is_empty() and not disrupt_four.is_empty() and int(disrupt_four.get("effect_score", 0)) >= int(disrupt_one.get("effect_score", 0))
	ok = ok and not steal_one.is_empty() and not steal_four.is_empty() and int(steal_four.get("gate_score", 0)) >= int(steal_one.get("gate_score", 0))
	ok = ok and not freeze_one.is_empty() and not freeze_four.is_empty() and int(freeze_four.get("control_gdp_penalty", 0)) > int(freeze_one.get("control_gdp_penalty", 0))
	ok = ok and not barrage_one.is_empty() and not barrage_four.is_empty() and int(barrage_four.get("global_barrage_target_count", 0)) > int(barrage_one.get("global_barrage_target_count", 0))
	ok = ok and String(report.get("summary", "")).contains("地区GDP份额门槛")
	if not ok:
		print("Direct interaction balance report: %s" % str(report))
	return ok


func _verify_temporary_decision_blueprints(main: Node) -> bool:
	var fixture_script := load("res://scripts/ui/temporary_decision_preview_fixtures.gd") as GDScript
	var overlay := main.find_child("OverlayLayer", true, false)
	if fixture_script == null or overlay == null or not overlay.has_method("show_temporary_decision"):
		return false
	var fixtures: RefCounted = fixture_script.new()
	var expected_panels := {
		"discard_purchase": "TemporaryChoiceDecisionPanel",
		"contract_response": "ContractResponseDecisionPanel",
		"monster_target_choice": "TemporaryChoiceDecisionPanel",
		"player_target_choice": "TemporaryChoiceDecisionPanel",
		"monster_wager": "MonsterWagerDecisionPanel",
	}
	for kind_variant: Variant in expected_panels:
		var kind := str(kind_variant)
		var data := fixtures.call("fixture", kind) as Dictionary
		if str(data.get("kind", "")) != kind or str(data.get("title", "")) == "":
			return false
		if not (data.get("actions", []) is Array) or (data.get("actions", []) as Array).is_empty():
			return false
		overlay.call("show_temporary_decision", data)
		var expected_panel_name := str(expected_panels[kind])
		for panel_name in ["MonsterWagerDecisionPanel", "ContractResponseDecisionPanel", "TemporaryChoiceDecisionPanel"]:
			var panel := overlay.find_child(panel_name, true, false) as Control
			if panel == null or panel.visible != (panel_name == expected_panel_name):
				return false
	var wager := fixtures.call("fixture", "monster_wager") as Dictionary
	var wager_data := wager.get("wager", {}) as Dictionary
	overlay.call("hide_confirm")
	return float(wager_data.get("timer", 0.0)) >= 20.0 and float(wager_data.get("timer", 0.0)) <= 30.0


func _verify_ai_monster_wager_policy(_main: Node) -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var main := packed.instantiate()
	var fixture_save_path := "user://test_runs/smoke_ai_monster_wager_fixture.save"
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", fixture_save_path))
	if not save_override_ready:
		main.free()
		return false
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	get_root().add_child(main)
	main.call("_new_game")
	main.set("opening_guide_dismissed", true)
	var ok := true
	var failures := []
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	if players.size() < 3:
		main.free()
		if FileAccess.file_exists(fixture_save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
		return false
	for i in range(players.size()):
		var player := (players[i] as Dictionary).duplicate(true)
		player["is_ai"] = i == 1 or i == 2
		player["seat_type"] = "ai" if bool(player.get("is_ai", false)) else "human"
		player["cash"] = 6200 if i == 1 else 3400
		player["cash_history"] = [int(player.get("cash", 0))]
		player["action_cooldown"] = 0.0
		players[i] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var district_index := _first_buildable_land_district(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts))
	if district_index < 0:
		district_index = maxi(0, int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district))
	var center := main.call("_district_center", district_index) as Vector2
	if CITY_FIXTURES.create_city_bool(main, 1, district_index, "AI赌局风险城"):
		ok = ok and _set_city_goods_for_test(main, district_index, "环晶电池", "星尘香料")
	var monster_a := _monster_controller(main).call("_make_auto_monster", 0, 0, district_index, 1, 4) as Dictionary
	var monster_b := _monster_controller(main).call("_make_auto_monster", 1, 1, district_index, 2, 1) as Dictionary
	monster_a["world_position"] = center
	monster_b["world_position"] = center
	monster_a["hp"] = 96
	monster_a["max_hp"] = 96
	monster_a["armor"] = 8
	monster_a["rank"] = 4
	monster_a["owner_revealed"] = false
	monster_b["hp"] = 16
	monster_b["max_hp"] = 16
	monster_b["armor"] = 0
	monster_b["rank"] = 1
	monster_b["owner_revealed"] = true
	main.set("auto_monsters", [monster_a, monster_b])
	main.set("active_monster_wagers", [])
	main.set("resolved_monster_wager_history", [])
	var ai1_cash_before := int((_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[1] as Dictionary).get("cash", 0))
	var wager_id := int(_monster_controller(main).call("_open_monster_wager_for_pair", 0, 1, "AI烟测赌局"))
	ok = ok and wager_id > 0
	var active := _as_array(main.get("active_monster_wagers"))
	if active.is_empty():
		failures.append("no active wager")
	else:
		var entry := active[0] as Dictionary
		var base_percent := int(entry.get("base_percent", 0))
		var bets := entry.get("bets", {}) as Dictionary
		var public_bets := _as_array(entry.get("public_bets", []))
		var ai1_bet := bets.get("1", {}) as Dictionary
		var summary := String(_monster_controller(main).call("_monster_wager_public_decision_summary", entry))
		var stake := int(ai1_bet.get("stake", 0))
		var stake_percent := int(ai1_bet.get("stake_percent", 0))
		var expected_stake := int(ceil(float(ai1_cash_before) * float(stake_percent) / 100.0))
		var cash_after := int((_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[1] as Dictionary).get("cash", 0))
		var public_ai1_line := false
		for public_variant in public_bets:
			var public_bet := public_variant as Dictionary
			if int(public_bet.get("player_index", -1)) == 1 and int(public_bet.get("stake", 0)) == stake and int(public_bet.get("stake_percent", 0)) == stake_percent and String(public_bet.get("side", "")) == "a":
				public_ai1_line = true
				break
		var metadata_ok := String(ai1_bet.get("side", "")) == "a" \
			and base_percent >= 5 \
			and base_percent <= 10 \
			and stake_percent >= base_percent \
			and stake_percent <= base_percent + 5 \
			and stake == expected_stake \
			and int(ai1_bet.get("ai_wager_score", 0)) > 0 \
			and int(ai1_bet.get("ai_wager_confidence", 0)) >= 150 \
			and String(ai1_bet.get("ai_wager_reason_key", "")) == "own_monster" \
			and int(ai1_bet.get("ai_wager_owner_bias", 0)) > 0 \
			and int(ai1_bet.get("ai_wager_stake_percent", 0)) == stake_percent
		ok = ok and metadata_ok
		ok = ok and cash_after == ai1_cash_before - stake
		ok = ok and public_ai1_line
		ok = ok and summary.contains("玩家2") and summary.contains("%") and summary.contains("¥%d" % stake)
		ok = ok and not summary.contains("ai_wager") and not summary.contains("score")
		if not metadata_ok:
			failures.append("ai1 bet side=%s percent=%d base=%d stake=%d expected=%d score=%d confidence=%d reason=%s owner=%d" % [
				String(ai1_bet.get("side", "")),
				stake_percent,
				base_percent,
				stake,
				expected_stake,
				int(ai1_bet.get("ai_wager_score", 0)),
				int(ai1_bet.get("ai_wager_confidence", 0)),
				String(ai1_bet.get("ai_wager_reason_key", "")),
				int(ai1_bet.get("ai_wager_owner_bias", 0)),
			])
		if not public_ai1_line:
			failures.append("public bet line missing")
	if not failures.is_empty():
		print("AI monster wager policy failures: %s" % " / ".join(failures))
	main.free()
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	return ok


func _verify_development_route_balance_baseline(main: Node) -> bool:
	var required_routes := ["city_growth", "contract_route", "finance_speculation", "monster_pressure", "intel_supply", "direct_interaction"]
	var audit := _diagnostics(main).development_route_audit()
	var by_id := {}
	for entry_variant in audit:
		var entry := entry_variant as Dictionary
		var route_id := String(entry.get("id", ""))
		if route_id != "":
			by_id[route_id] = entry
	for route_variant in required_routes:
		var route_id := String(route_variant)
		if not by_id.has(route_id):
			print("Missing development route audit entry: %s" % route_id)
			return false
		var entry: Dictionary = by_id[route_id]
		var min_cards := 2 if route_id == "direct_interaction" else 3
		if int(entry.get("card_count", 0)) < min_cards:
			print("Development route has too few cards: %s count=%d" % [route_id, int(entry.get("card_count", 0))])
			return false
		if int(entry.get("budget_total", 0)) <= 0:
			print("Development route has no strength budget: %s" % route_id)
			return false
		if int(entry.get("budget_min", 0)) <= 0 or int(entry.get("budget_max", 0)) < int(entry.get("budget_min", 0)):
			print("Development route has invalid budget range: %s min=%d max=%d" % [route_id, int(entry.get("budget_min", 0)), int(entry.get("budget_max", 0))])
			return false
		if not (entry.get("budget_band_counts", {}) is Dictionary) or (entry.get("budget_band_counts", {}) as Dictionary).is_empty():
			print("Development route has no budget band distribution: %s" % route_id)
			return false
		if not (entry.get("pillar_counts", {}) is Dictionary) or (entry.get("pillar_counts", {}) as Dictionary).size() < 2:
			print("Development route has too few balance pillars: %s -> %s" % [route_id, str(entry.get("pillar_counts", {}))])
			return false
		var pillar_summary := _diagnostics(main).development_route_pillar_summary(entry)
		match route_id:
			"city_growth":
				if not pillar_summary.contains("收益"):
					print("City-growth route lacks income pillar: %s" % pillar_summary)
					return false
			"contract_route":
				if not pillar_summary.contains("合约"):
					print("Contract route lacks contract pillar: %s" % pillar_summary)
					return false
			"finance_speculation":
				if not pillar_summary.contains("GDP金融") and not pillar_summary.contains("市场"):
					print("Finance route lacks GDP/market pillar: %s" % pillar_summary)
					return false
			"monster_pressure":
				if not pillar_summary.contains("怪兽") or not pillar_summary.contains("压制"):
					print("Monster-pressure route lacks monster/pressure pillars: %s" % pillar_summary)
					return false
			"intel_supply":
				if not pillar_summary.contains("信息") or not pillar_summary.contains("补给"):
					print("Intel-supply route lacks intel/supply pillars: %s" % pillar_summary)
					return false
			"direct_interaction":
				if not pillar_summary.contains("互动") or not pillar_summary.contains("压制"):
					print("Direct-interaction route lacks interaction/pressure pillars: %s" % pillar_summary)
					return false
		var balance_status := String(entry.get("balance_status", ""))
		if not ["健康", "可调", "待补强"].has(balance_status):
			print("Development route has invalid balance status: %s -> %s" % [route_id, balance_status])
			return false
		if not (entry.get("balance_notes", []) is Array):
			print("Development route balance notes are not structured: %s" % route_id)
			return false
		var balance_summary := _diagnostics(main).development_route_balance_summary(route_id)
		if not balance_summary.contains("强度区间") or not balance_summary.contains("预算分布") or not balance_summary.contains("支点") or not balance_summary.contains("平衡") or not balance_summary.contains("检查") or not balance_summary.contains("打法") or not balance_summary.contains("反制"):
			print("Development route balance summary is incomplete: %s -> %s" % [route_id, balance_summary])
			return false
		if int(entry.get("complete_rank_ladders", 0)) <= 0:
			print("Development route has no complete I-IV ladder: %s" % route_id)
			return false
		if _as_array(entry.get("sample_cards", [])).is_empty():
			print("Development route has no sample cards: %s" % route_id)
			return false
	var preference_coverage := _ai_controller(main).call("_ai_development_route_preference_audit") as Dictionary
	for route_variant in required_routes:
		var route_id := String(route_variant)
		if int(preference_coverage.get(route_id, 0)) <= 0:
			print("No AI personality prefers development route: %s" % route_id)
			return false
	var diversity_audit := _ai_controller(main).call("_ai_development_route_diversity_audit") as Dictionary
	if int(diversity_audit.get("profile_count", 0)) < 6:
		print("AI route diversity audit covers too few personality profiles")
		return false
	if int(diversity_audit.get("covered_core_route_count", 0)) < required_routes.size():
		print("AI primary-route diversity does not cover all core routes: %s" % str(diversity_audit.get("missing_core_routes", [])))
		return false
	var primary_counts := diversity_audit.get("primary_counts", {}) as Dictionary
	for route_variant in required_routes:
		var route_id := String(route_variant)
		if int(primary_counts.get(route_id, 0)) <= 0:
			print("No AI personality has primary route: %s" % route_id)
			return false
	var diversity_summary := String(_ai_controller(main).call("_ai_development_route_diversity_summary"))
	if not diversity_summary.contains("核心路线6/6覆盖") or not diversity_summary.contains("城市成长") or not diversity_summary.contains("金融投机") or not diversity_summary.contains("怪兽压制") or not diversity_summary.contains("直接互动"):
		print("AI route diversity summary is incomplete: %s" % diversity_summary)
		return false
	if int(_ai_controller(main).call("_ai_development_route_bonus", 1, "city_growth")) <= 0:
		print("First AI profile does not receive a positive city-growth route bonus")
		return false
	return true


func _verify_development_route_pressure_audit(main: Node) -> bool:
	var required_routes := ["city_growth", "contract_route", "finance_speculation", "monster_pressure", "intel_supply", "direct_interaction"]
	var report := _diagnostics(main).development_route_pressure_audit()
	var routes := _as_array(report.get("routes", []))
	var issues := _as_array(report.get("issues", []))
	if not bool(report.get("ok", false)):
		print("Development route pressure audit issues: %s" % " / ".join(issues))
		return false
	var by_id := {}
	for route_variant in routes:
		if not (route_variant is Dictionary):
			continue
		var route := route_variant as Dictionary
		var route_id := String(route.get("id", ""))
		if route_id != "":
			by_id[route_id] = route
	for route_variant in required_routes:
		var route_id := String(route_variant)
		if not by_id.has(route_id):
			print("Missing pressure route: %s" % route_id)
			return false
		var route := by_id[route_id] as Dictionary
		var status := String(route.get("status", ""))
		var notes := _as_array(route.get("notes", []))
		var total_pressure := int(route.get("total_pressure", 0))
		var gate_score := int(route.get("gate_score", 0))
		var clue_score := int(route.get("public_clue_score", 0))
		var counter_score := int(route.get("counterplay_score", 0))
		var money_score := int(route.get("money_score", 0))
		var disruption_score := int(route.get("disruption_score", 0))
		var intel_supply_score := int(route.get("intel_supply_score", 0))
		var ok := status == "可追目标" \
			and notes.is_empty() \
			and int(route.get("card_count", 0)) >= 8 \
			and int(route.get("complete_rank_ladders", 0)) >= 1 \
			and total_pressure >= 160 \
			and gate_score >= 120 \
			and clue_score >= 80 \
			and counter_score >= 130 \
			and int(route.get("primary_ai_profiles", 0)) >= 1 \
			and not _as_array(route.get("sample_cards", [])).is_empty()
		match route_id:
			"city_growth":
				ok = ok and money_score > 0
			"contract_route":
				ok = ok and money_score > 0 and gate_score > 0
			"finance_speculation":
				ok = ok and money_score > 0 and clue_score > 0
			"monster_pressure":
				ok = ok and disruption_score > 0
			"intel_supply":
				ok = ok and intel_supply_score > 0
			"direct_interaction":
				ok = ok and disruption_score > 0 and clue_score > 0
		if not ok:
			print("Development route pressure failed %s: %s" % [route_id, str(route)])
			return false
	var summary := String(report.get("summary", ""))
	if not summary.contains("核心路线压力审计") or not summary.contains("城市成长") or not summary.contains("金融投机") or not summary.contains("直接互动"):
		print("Development route pressure summary incomplete: %s" % summary)
		return false
	return true


func _verify_playable_card_resolution_coverage(main: Node) -> bool:
	var report := _diagnostics(main).playable_card_resolution_coverage_report()
	var missing := _as_array(report.get("missing", []))
	if not missing.is_empty():
		print("Missing playable card resolution handlers: %s" % " / ".join(missing))
		return false
	var checked := int(report.get("checked", 0))
	if checked < 120:
		print("Playable card resolution coverage checked too few cards: %d" % checked)
		return false
	return true


func _all_card_supply_entries_are_base_rank(main: Node, districts: Array) -> bool:
	for name_variant in _as_array(main.get("skill_market")):
		var skill_name := String(name_variant)
		if skill_name != "" and _skill_rank(skill_name) != 1:
			print("Non-base card in run market: %s" % skill_name)
			return false
	for name_variant in _as_array(main.call("_card_codex_names", "all")):
		var card_name := String(name_variant)
		if card_name != "" and _skill_rank(card_name) != 1:
			print("Non-base card in codex index: %s" % card_name)
			return false
	for district_variant in districts:
		var district := district_variant as Dictionary
		for card_variant in _as_array(district.get("card_choices", [])):
			var card_name := String(card_variant)
			if card_name != "" and _skill_rank(card_name) != 1:
				print("Non-base card in district supply: %s" % card_name)
				return false
	return true


func _variant_has_dictionary_key(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		var dict := value as Dictionary
		if dict.has(target_key):
			return true
		for key_variant in dict.keys():
			if _variant_has_dictionary_key(dict[key_variant], target_key):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _variant_has_dictionary_key(item_variant, target_key):
				return true
	return false


func _verify_monster_duration_expiry(main: Node) -> bool:
	var before := _as_array(main.get("auto_monsters"))
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if before.is_empty() or districts.is_empty():
		return false
	var landing := clampi(int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district), 0, districts.size() - 1)
	var expiring := _monster_controller(main).call("_make_auto_monster", before.size(), 0, landing, 0, 1) as Dictionary
	var expiring_uid := int(expiring.get("uid", 0))
	expiring["down"] = true
	expiring["remaining_time"] = 0.01
	var expanded := before.duplicate(true)
	expanded.append(expiring)
	main.set("auto_monsters", expanded)
	_monster_controller(main).call("_update_auto_monster_durations", 0.02)
	var after := _as_array(main.get("auto_monsters"))
	if after.size() != before.size():
		return false
	for actor_variant in after:
		var actor := actor_variant as Dictionary
		if int(actor.get("uid", 0)) == expiring_uid:
			return false
	return true


func _verify_monster_card_runtime_overrides(main: Node) -> bool:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if players.is_empty() or districts.is_empty():
		return false
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var previous_selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	var previous_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var test_monsters := []
	for actor_variant in previous_monsters:
		var actor := actor_variant as Dictionary
		if int(actor.get("owner", -1)) != 0:
			test_monsters.append(actor)
	main.set("auto_monsters", test_monsters)
	var before_count := test_monsters.size()
	var card := main.call("_make_skill", main.call("_monster_card_name", 0, 1)) as Dictionary
	card["starter_play_free"] = true
	card["summon_access"] = "any"
	card["hp"] = 77
	card["duration"] = 13.5
	card["move"] = 333.0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = clampi(int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district), 0, districts.size() - 1)
	if not bool(_monster_controller(main).call("_summon_monster_from_card", players[0] as Dictionary, card)):
		main.set("auto_monsters", previous_monsters)
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
		return false
	var after := _as_array(main.get("auto_monsters"))
	if after.size() != before_count + 1:
		main.set("auto_monsters", previous_monsters)
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
		return false
	var actor := after[after.size() - 1] as Dictionary
	var matches := int(actor.get("hp", 0)) == 77 \
		and int(actor.get("max_hp", 0)) == 77 \
		and is_equal_approx(float(actor.get("duration", 0.0)), 13.5) \
		and is_equal_approx(float(actor.get("remaining_time", 0.0)), 13.5) \
		and is_equal_approx(float(actor.get("move", 0.0)), 333.0)
	main.set("auto_monsters", previous_monsters)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
	return matches


func _verify_monster_card_play_cash_cost(main: Node) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var monster_count := _as_array(main.get("auto_monsters")).size()
	if previous_players.is_empty() or monster_count <= 0:
		return false
	var card := main.call("_make_skill", main.call("_monster_card_name", 0, 1)) as Dictionary
	var expected_cost := monster_count * 100
	if int((main.call("_card_play_requirement_snapshot", 0, card) as Dictionary).get("cash_cost", 0)) != expected_cost:
		return false
	var players := previous_players.duplicate(true)
	var player := players[0] as Dictionary
	var slots := _as_array(player.get("slots", [])).duplicate(true)
	var slot_index := slots.size()
	slots.append(card)
	player["slots"] = slots
	player["cash"] = 5000
	player["total_card_spend"] = 37
	player["economic_ledger"] = []
	players[0] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	main.call("_finish_played_skill", 0, slot_index, card, 0.0)
	var after_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_player := after_players[0] as Dictionary
	var after_slots := _as_array(after_player.get("slots", []))
	var ledger := _as_array(after_player.get("economic_ledger", []))
	var ledger_ok := false
	for entry_variant in ledger:
		var entry := entry_variant as Dictionary
		if String(entry.get("kind", "")) == "卡牌支出" \
			and int(entry.get("amount", 0)) == -expected_cost \
			and String(entry.get("label", "")).contains("怪兽·孢雾海皇 I级"):
			ledger_ok = true
			break
	var result := int(after_player.get("cash", 0)) == 5000 - expected_cost \
		and int(after_player.get("total_card_spend", 0)) == 37 + expected_cost \
		and slot_index < after_slots.size() \
		and after_slots[slot_index] == null \
		and ledger_ok
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	return result


func _verify_ranked_monster_public_action_probabilities(main: Node, actor: Dictionary) -> bool:
	var catalog_index := int(actor.get("catalog_index", 0))
	return _verify_monster_catalog_public_probability_contract(main, catalog_index)


func _verify_monster_catalog_public_probability_contract(main: Node, catalog_index: int) -> bool:
	var monster := _monster_controller(main)
	if monster == null or not monster.has_method("monster_codex_public_catalog_source_v06"):
		return false
	var value: Variant = monster.call("monster_codex_public_catalog_source_v06", catalog_index)
	var source := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return _monster_public_probability_source_ok(source)


func _monster_public_probability_source_ok(source: Dictionary) -> bool:
	if not bool(source.get("valid", false)):
		return false
	if _monster_probability_text_has_raw_weight(str(source.get("rank_iv_probability_summary", ""))):
		return false
	var ecology := source.get("ecology", {}) as Dictionary
	if _monster_probability_text_has_raw_weight(str(ecology.get("rank_iv_probability_shift", ""))):
		return false
	var actions := _as_array(source.get("actions", []))
	if actions.is_empty():
		return false
	var has_probability_row := false
	var has_i_to_iv_progression := false
	var has_destroyed_progression := false
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action := action_variant as Dictionary
		var i_open := _monster_public_probability_percent_value(action.get("i_open", ""))
		var i_destroyed := _monster_public_probability_percent_value(action.get("i_destroyed", ""))
		var iv_open := _monster_public_probability_percent_value(action.get("iv_open", ""))
		var iv_destroyed := _monster_public_probability_percent_value(action.get("iv_destroyed", ""))
		if i_open < 0 or i_destroyed < 0 or iv_open < 0 or iv_destroyed < 0:
			return false
		var tooltip := str(action.get("probability_tooltip", ""))
		if not (tooltip.contains("I开局") and tooltip.contains("I破坏后") and tooltip.contains("IV开局") and tooltip.contains("IV破坏后")):
			return false
		if _monster_probability_text_has_raw_weight(tooltip):
			return false
		has_probability_row = true
		has_i_to_iv_progression = has_i_to_iv_progression or iv_open != i_open
		has_destroyed_progression = has_destroyed_progression or i_destroyed != i_open or iv_destroyed != iv_open
	return has_probability_row and has_i_to_iv_progression and has_destroyed_progression


func _monster_public_probability_percent_value(value: Variant) -> int:
	var text := str(value).strip_edges()
	if not text.ends_with("%"):
		return -1
	text = text.trim_suffix("%").strip_edges()
	if not text.is_valid_int():
		return -1
	var percent := int(text)
	return percent if percent >= 0 and percent <= 100 else -1


func _monster_probability_text_has_raw_weight(text: String) -> bool:
	var lower := text.to_lower()
	for token in ["weight", "raw_weight", "weight_delta", "numerator", "denominator", "total_weight", "rng", "actual_target", "committed_target"]:
		if lower.contains(token):
			return true
	return text.contains("权重") or text.contains("分子") or text.contains("分母") or text.contains("随机票")


func _verify_monster_ecology_balance_audit(main: Node) -> bool:
	var report := _diagnostics(main).monster_ecology_balance_report()
	var issues := _as_array(report.get("issues", []))
	if not bool(report.get("ok", false)):
		print("Monster ecology balance issues: %s" % " / ".join(issues))
		return false
	var catalog_count := int(report.get("catalog_count", 0))
	var movement_counts := report.get("movement_counts", {}) as Dictionary
	var summary := String(report.get("summary", ""))
	var entries := _as_array(report.get("entries", []))
	if catalog_count < 8 or entries.size() != catalog_count:
		print("Monster ecology catalog count mismatch: %d entries=%d" % [catalog_count, entries.size()])
		return false
	if int(movement_counts.get("飞行", 0)) <= 0 or int(movement_counts.get("水栖/海域", 0)) <= 0 or int(movement_counts.get("陆行", 0)) <= 0:
		print("Monster ecology movement coverage too narrow: %s" % str(movement_counts))
		return false
	if int(report.get("resource_good_count", 0)) < 12:
		print("Monster ecology resource pool too small: %d" % int(report.get("resource_good_count", 0)))
		return false
	if int(report.get("action_signature_count", 0)) < catalog_count - 1:
		print("Monster ecology signatures too similar: %d/%d" % [int(report.get("action_signature_count", 0)), catalog_count])
		return false
	if int(report.get("role_tag_count", 0)) < 8:
		print("Monster ecology role tags too few: %d" % int(report.get("role_tag_count", 0)))
		return false
	if int(report.get("monsters_with_resource_focus", 0)) != catalog_count \
		or int(report.get("monsters_with_economy_boon", 0)) != catalog_count \
		or int(report.get("monsters_with_art", 0)) != catalog_count \
		or int(report.get("monsters_with_late_shift", 0)) != catalog_count \
		or int(report.get("monsters_with_bound_ladder", 0)) != catalog_count:
		print("Monster ecology coverage incomplete: %s" % str(report))
		return false
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			return false
		var entry := entry_variant as Dictionary
		var role_tags := _as_array(entry.get("role_tags", []))
		var bound_counts := _as_array(entry.get("bound_skill_counts", []))
		var ecology_score := int(entry.get("ecology_score", 0))
		if int(entry.get("action_count", 0)) < 6 \
			or int(entry.get("active_early_actions", 0)) < 3 \
			or int(entry.get("active_escalated_actions", 0)) < 5 \
			or int(entry.get("resource_focus_count", 0)) < 2 \
			or role_tags.size() < 3 \
			or ecology_score < 170:
			print("Monster ecology entry weak: %s" % str(entry))
			return false
		for rank in range(1, 5):
			if rank - 1 >= bound_counts.size() or int(bound_counts[rank - 1]) < rank:
				print("Monster bound skill ladder weak: %s" % str(entry))
				return false
	if not summary.contains("怪兽生态审计") or not summary.contains("移动:") or not summary.contains("商品偏好"):
		print("Monster ecology summary incomplete: %s" % summary)
		return false
	return true


func _verify_anonymous_cash_card(main: Node) -> bool:
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	var test_slot := 10
	_set_player_skill(main, 0, test_slot, "轨道融资1")
	_clear_player_cooldown(main, 0)
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var player_name := String((players[0] as Dictionary).get("name", "玩家1"))
	var cash_before := int((players[0] as Dictionary).get("cash", 0))
	var marker := "SMOKE_ANON_CASH_START"
	main.call("_log", marker)
	main.call("_use_skill", test_slot)
	_clear_player_cooldown(main, 0)
	players = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	return int((players[0] as Dictionary).get("cash", 0)) > cash_before \
		and _log_after_marker_hides_player(main, marker, "轨道融资1", player_name) \
		and _card_callouts_hide_player(main, "轨道融资1", player_name)


func _verify_anonymous_direct_command(main: Node) -> bool:
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	var test_slot := 11
	_set_player_skill(main, 0, test_slot, "垂直裂刃窗口1")
	_clear_player_cooldown(main, 0)
	var actors := _as_array(main.get("auto_monsters"))
	if actors.is_empty():
		return false
	var armor_before := int((actors[0] as Dictionary).get("armor", 0))
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var player_name := String((players[0] as Dictionary).get("name", "玩家1"))
	var marker := "SMOKE_ANON_COMMAND_START"
	main.call("_log", marker)
	main.call("_use_skill", test_slot)
	if not bool(main.call("_has_pending_target_choice")):
		return false
	main.call("_choose_pending_target_monster", 0)
	_clear_player_cooldown(main, 0)
	actors = _as_array(main.get("auto_monsters"))
	return int((actors[0] as Dictionary).get("armor", 0)) > armor_before \
		and _log_after_marker_hides_player(main, marker, "垂直裂刃窗口1", player_name) \
		and _card_callouts_hide_player(main, "垂直裂刃窗口1", player_name)


func _first_lure_target_district(main: Node, current_position: int) -> int:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	for i in range(districts.size()):
		if i == current_position:
			continue
		var district := districts[i] as Dictionary
		if bool(district.get("destroyed", false)):
			continue
		return i
	return -1


func _verify_monster_lure_replaces_control_window(_main: Node) -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var main := packed.instantiate()
	var fixture_save_path := "user://test_runs/smoke_monster_lure_fixture.save"
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", fixture_save_path))
	if not save_override_ready:
		main.free()
		return false
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	get_root().add_child(main)
	main.call("_new_game")
	main.set("opening_guide_dismissed", true)
	var ok := true
	var failures := []
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	if main_source.contains("control_gain"):
		failures.append("source still contains control_gain")
		ok = false
	if main_source.contains("行动窗口"):
		failures.append("source still contains old action-window wording")
		ok = false
	var skill := main.call("_make_skill", "诱导电波1") as Dictionary
	if String(skill.get("kind", "")) != "monster_lure":
		failures.append("skill kind is not monster_lure")
		ok = false
	if not String(skill.get("text", "")).contains("下一次自动移动"):
		failures.append("skill text does not describe next automatic movement")
		ok = false
	if String(skill.get("text", "")).contains("持续控制"):
		failures.append("skill text still mentions persistent control")
		ok = false
	var coordinator := _runtime_card_coordinator(main)
	var card_presentation_variant: Variant = coordinator.call("compose_card_presentation", {
		"card_name": "诱导电波1",
		"display_name": main.call("_card_display_name", "诱导电波1"),
		"skill": skill,
		"rank": 1,
	}) if coordinator != null else {}
	var card_presentation: Dictionary = card_presentation_variant if card_presentation_variant is Dictionary else {}
	if not String(card_presentation.get("rules_text_full", "")).contains("下一次自动移动"):
		failures.append("card facts do not include lure speedup")
		ok = false
	var resolution_presentation_variant: Variant = coordinator.call("compose_card_resolution_presentation", {
		"card": {
			"card_name": "诱导电波1",
			"display_name": main.call("_card_display_name", "诱导电波1"),
			"skill": skill,
			"targets_monster": true,
		},
		"skill": skill,
		"targets_monster": true,
		"seconds_left": 1.0,
		"display_duration": 1.0,
	}) if coordinator != null else {}
	var resolution_presentation: Dictionary = resolution_presentation_variant if resolution_presentation_variant is Dictionary else {}
	if not String(resolution_presentation.get("animation_catalog_text", "")).contains("一次性诱导"):
		failures.append("animation text does not include one-shot lure")
		ok = false
	var monster_owner := _monster_controller(main)
	var actors := _as_array(main.get("auto_monsters"))
	if actors.is_empty() and monster_owner != null:
		var start_district := -1
		for district_index in range(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).size()):
			var district := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)[district_index] as Dictionary
			if not bool(district.get("destroyed", false)):
				start_district = district_index
				break
		if start_district >= 0:
			var fixture_actor := monster_owner.call("_make_auto_monster", 0, 0, start_district, 1, 1) as Dictionary
			var monster_state := monster_owner.call("to_save_data") as Dictionary
			monster_state["auto_monsters"] = [fixture_actor]
			var monster_restore := monster_owner.call("apply_save_data", monster_state) as Dictionary
			if not bool(monster_restore.get("applied", false)):
				failures.append("monster owner fixture rejected")
				ok = false
			actors = _as_array(main.get("auto_monsters"))
	if actors.is_empty():
		failures.append("no field monsters")
		ok = false
	else:
		var actor := (actors[0] as Dictionary).duplicate(true)
		var target_index := _first_lure_target_district(main, int(actor.get("position", -1)))
		if target_index < 0:
			failures.append("no lure target district")
			ok = false
		else:
			actor["move"] = 99999.0
			actors[0] = actor
			for other_index in range(1, actors.size()):
				var isolated_other := (actors[other_index] as Dictionary).duplicate(true)
				isolated_other["down"] = true
				actors[other_index] = isolated_other
			main.set("auto_monsters", actors)
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = target_index
			var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
			var distance_before := float(main.call("_entity_distance_to_district", actor, target_index))
			if not bool(main.call("_resolve_targeted_skill", skill, players[0] as Dictionary, 0, 0)):
				failures.append("resolve targeted lure returned false")
				ok = false
			actors = _as_array(main.get("auto_monsters"))
			var lured_actor := actors[0] as Dictionary
			if int(lured_actor.get("lure_target_district", -1)) != target_index:
				failures.append("lure target was not stored")
				ok = false
			if int(lured_actor.get("lure_moves_left", 0)) != 1:
				failures.append("lure move count was not stored")
				ok = false
			var lure_callout_seen := _callouts_contain(_visual_cue_array(main, "action_callouts"), "诱导")
			_monster_controller(main).call("_auto_monster_movement_tick")
			_monster_controller(main).call("_update_auto_monster_linear_movement", 1.0)
			actors = _as_array(main.get("auto_monsters"))
			var after_actor := actors[0] as Dictionary
			var distance_after := float(main.call("_entity_distance_to_district", after_actor, target_index))
			if int(after_actor.get("position", -1)) != target_index and distance_after >= distance_before:
				failures.append("lured monster did not move closer to target")
				ok = false
			if after_actor.has("lure_target_district") or after_actor.has("lure_moves_left"):
				failures.append("lure marker did not expire")
				ok = false
			if not _log_contains(main, "匿名诱导"):
				failures.append("lure log missing")
				ok = false
			if not lure_callout_seen and not _callouts_contain(_visual_cue_array(main, "action_callouts"), "诱导"):
				failures.append("lure callout missing")
				ok = false
	if not failures.is_empty():
		print("Monster lure verification failures: %s" % " / ".join(failures))
	main.free()
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	return ok


func _verify_agent_policy_audit_report(main: Node) -> bool:
	if not _ai_controller(main).has_method("_agent_policy_audit_report"):
		print("Agent audit helper missing")
		return false
	var report := _ai_controller(main).call("_agent_policy_audit_report") as Dictionary
	var failures := []
	if not bool(report.get("test_only", false)):
		failures.append("report is not marked test_only")
	if int(report.get("ai_player_count", 0)) < EXPECTED_AI_PLAYER_COUNT:
		failures.append("missing AI player reports")
	if not (report.get("playable_missing_handlers", []) as Array).is_empty():
		failures.append("playable missing handlers: %s" % str(report.get("playable_missing_handlers", [])))
	var monster_target := report.get("monster_target", {}) as Dictionary
	if not bool(monster_target.get("destroyed_zero_ok", false)):
		failures.append("monster target destroyed_zero_ok false")
	if int(monster_target.get("actor_count", 0)) > 0 and not bool(monster_target.get("any_positive_alive", false)):
		failures.append("no positive alive monster target")
	var hidden_info := report.get("hidden_info", {}) as Dictionary
	if int(hidden_info.get("leak_count", -1)) != 0:
		failures.append("hidden leak report: %s" % str(hidden_info.get("leaks", [])))
	var ai_reports := _as_array(report.get("ai_players", []))
	var required_groups := ["card_play", "card_buy", "auction", "counter", "contract", "intel", "monster_wager", "military", "weather"]
	var saw_candidate_group := false
	for ai_report_variant in ai_reports:
		if not (ai_report_variant is Dictionary):
			failures.append("non-dictionary AI report")
			continue
		var ai_report := ai_report_variant as Dictionary
		var groups := ai_report.get("groups", {}) as Dictionary
		for group_name_variant in required_groups:
			var group_name := String(group_name_variant)
			if not groups.has(group_name):
				failures.append("missing policy group %s for AI %d" % [group_name, int(ai_report.get("player_index", -1))])
				continue
			var group := groups[group_name] as Dictionary
			if bool(group.get("has_candidates", false)):
				saw_candidate_group = true
				if not (group.get("missing_policy_kind", []) as Array).is_empty():
					failures.append("%s missing policy kind: %s" % [group_name, str(group.get("missing_policy_kind", []))])
				if not (group.get("missing_training_metadata", []) as Array).is_empty():
					failures.append("%s missing trainable metadata: %s" % [group_name, str(group.get("missing_training_metadata", []))])
				if not (group.get("negative_anomalies", []) as Array).is_empty():
					failures.append("%s negative anomalies: %s" % [group_name, str(group.get("negative_anomalies", []))])
	if not saw_candidate_group:
		failures.append("no AI candidate group available")
	if not failures.is_empty():
		print("Agent policy audit failures: %s" % " / ".join(failures))
		return false
	return true


func _first_alive_district_index_for_test(districts: Array) -> int:
	for i in range(districts.size()):
		if not bool((districts[i] as Dictionary).get("destroyed", false)):
			return i
	return -1


func _reset_card_resolution_state_for_test(main: Node) -> void:
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("active_card_resolution", {})
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_simultaneous_timer", 0.0)
	main.set("card_resolution_auction_timer", 0.0)
	main.set("card_resolution_counter_window_active", false)
	main.set("card_resolution_counter_timer", 0.0)
	main.set("card_resolution_force_simultaneous_window", -1.0)


func _verify_hidden_info_leak_audit(main: Node) -> bool:
	main.call("_refresh_ui")
	if not _ai_controller(main).has_method("_hidden_info_leak_audit"):
		print("Hidden info leak audit helper missing")
		return false
	var report := _ai_controller(main).call("_hidden_info_leak_audit") as Dictionary
	var ok := bool(report.get("test_only", false)) \
		and int(report.get("checked_text_count", 0)) > 0 \
		and int(report.get("leak_count", -1)) == 0
	if not ok:
		print("Hidden info leak audit failed: %s" % str(report))
	return ok


func _map_view_uses_unified_monster_markers() -> bool:
	var source := FileAccess.get_file_as_string(MAP_VIEW_SCRIPT_PATH)
	return source.contains("auto_monster_markers") \
		and not source.contains("monster_world_position") \
		and not source.contains("rival_monster_world_position") \
		and not source.contains("_legacy_monsters_visible")


func _map_view_has_betting_table_theme() -> bool:
	var script := load(MAP_VIEW_SCRIPT_PATH) as Script
	if script == null:
		return false
	var map_view := script.new() as Control
	if map_view == null or not map_view.has_method("betting_table_theme_report"):
		if map_view != null:
			map_view.free()
		return false
	var report := map_view.call("betting_table_theme_report") as Dictionary
	map_view.free()
	return bool(report.get("enabled", false)) \
		and String(report.get("name", "")).contains("赌桌") \
		and String(report.get("felt_color", "")) == "#052e24" \
		and String(report.get("rim_color", "")) == "#d6a440" \
		and int(report.get("chip_count", 0)) >= 12 \
		and int(report.get("seat_count", 0)) >= 6 \
		and String(report.get("planet_center_policy", "")) == "globe_center" \
		and String(report.get("detail_policy", "")).contains("edge_icons")


func _log_after_marker_hides_player(main: Node, marker: String, card_name: String, player_name: String) -> bool:
	var after_marker := false
	var found_card := false
	var visible_name := String(main.call("_card_display_name", card_name)) if main.has_method("_card_display_name") else ""
	for line_variant in _public_log_messages(main):
		var line := String(line_variant)
		if line.contains(marker):
			after_marker = true
			continue
		if not after_marker:
			continue
		found_card = found_card or line.contains(card_name) or (visible_name != "" and line.contains(visible_name))
		if line.contains(player_name):
			return false
	return after_marker and found_card


func _card_callouts_hide_player(main: Node, card_name: String, player_name: String) -> bool:
	var found_card := false
	var visible_name := String(main.call("_card_display_name", card_name)) if main.has_method("_card_display_name") else ""
	for callout_variant in _visual_cue_array(main, "action_callouts"):
		var callout := callout_variant as Dictionary
		var text := "%s %s %s" % [callout.get("actor", ""), callout.get("action", ""), callout.get("detail", "")]
		if not text.contains(card_name) and not (visible_name != "" and text.contains(visible_name)):
			continue
		found_card = true
		if text.contains(player_name):
			return false
	return found_card


func _economy_ledgers_respect_active_view(main: Node) -> bool:
	var selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	var dashboard_snapshot := main.call("_economy_dashboard_public_snapshot") as Dictionary
	var summary_text := str(dashboard_snapshot.get("summary_text", ""))
	if summary_text == "":
		return false
	for entry_variant in _as_array(main.call("_economy_player_cash_entries")):
		var entry := entry_variant as Dictionary
		var ledger := String(entry.get("ledger", ""))
		var player_name := str(entry.get("name", "玩家"))
		if int(entry.get("player_index", -1)) == selected_player:
			if ledger == "私人账本（不公开）" or bool(entry.get("private", true)) or not summary_text.contains(player_name):
				return false
		else:
			if ledger != "私人账本（不公开）" or not bool(entry.get("private", false)):
				return false
			if not summary_text.contains("%s｜现金、结算预估、城市资产、现金流、资金轨迹与流水均为私人信息" % player_name):
				return false
	return true


func _player_has_bound_monster_skill(players: Array, player_index: int) -> bool:
	return _player_bound_monster_skill_count(players, player_index) > 0


func _player_bound_monster_skill_count(players: Array, player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var player := players[player_index] as Dictionary
	var count := 0
	for skill_variant in _as_array(player.get("slots", [])):
		if skill_variant == null:
			continue
		var skill := skill_variant as Dictionary
		if String(skill.get("kind", "")) == "monster_bound_action" and bool(skill.get("persistent", false)):
			count += 1
	return count


func _verify_bound_monster_skill_persistence(main: Node) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	if previous_players.is_empty():
		return false
	var player_index := -1
	var slot_index := -1
	var skill := {}
	for i in range(previous_players.size()):
		var player := previous_players[i] as Dictionary
		var slots := _as_array(player.get("slots", []))
		for j in range(slots.size()):
			if slots[j] == null:
				continue
			var candidate := slots[j] as Dictionary
			if String(candidate.get("kind", "")) == "monster_bound_action" and bool(candidate.get("persistent", false)):
				player_index = i
				slot_index = j
				skill = candidate.duplicate(true)
				break
		if player_index >= 0:
			break
	if player_index < 0 or slot_index < 0:
		return false
	main.call("_finish_played_skill", player_index, slot_index, skill, 0.0)
	var after_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var after_player := after_players[player_index] as Dictionary
	var after_slots := _as_array(after_player.get("slots", []))
	var result := slot_index < after_slots.size() and after_slots[slot_index] != null
	if result:
		var after_skill := after_slots[slot_index] as Dictionary
		result = String(after_skill.get("name", "")) == String(skill.get("name", "")) \
			and String(after_skill.get("kind", "")) == "monster_bound_action" \
			and bool(after_skill.get("persistent", false)) \
			and float(after_skill.get("cooldown_left", 0.0)) > 0.0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	return result


func _callouts_contain(callouts: Array, needle: String) -> bool:
	for callout_variant in callouts:
		var callout := callout_variant as Dictionary
		if String(callout.get("actor", "")).contains(needle) or String(callout.get("action", "")).contains(needle) or String(callout.get("detail", "")).contains(needle):
			return true
	return false


func _log_contains(main: Node, needle: String) -> bool:
	for line_variant in _public_log_messages(main):
		if String(line_variant).contains(needle):
			return true
	return false


func _player_card_names(players: Array, player_index: int) -> Array:
	var result := []
	if player_index < 0 or player_index >= players.size():
		return result
	var player := players[player_index] as Dictionary
	for skill_variant in _as_array(player.get("slots", [])):
		if skill_variant == null:
			continue
		var skill := skill_variant as Dictionary
		result.append(String(skill.get("name", "")))
	return result


func _player_cash(players: Array, player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var player := players[player_index] as Dictionary
	return int(player.get("cash", 0))


func _intel_cash_from_stats(main: Node, player_index: int) -> int:
	var stats_variant: Variant = main.call("_player_intel_stats", player_index)
	var stats: Dictionary = stats_variant if stats_variant is Dictionary else {}
	return int(stats.get("cash", 0))


func _player_total_card_spend(players: Array, player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var player := players[player_index] as Dictionary
	return int(player.get("total_card_spend", 0))


func _player_ledger_contains(players: Array, player_index: int, needle: String) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	for entry_variant in _as_array(player.get("economic_ledger", [])):
		var entry := entry_variant as Dictionary
		if String(entry.get("kind", "")).contains(needle) or String(entry.get("label", "")).contains(needle) or String(entry.get("detail", "")).contains(needle):
			return true
	return false


func _rival_active_city_count(main: Node, active_player_index: int) -> int:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var total := 0
	for i in range(players.size()):
		if i == active_player_index:
			continue
		total += int(main.call("_player_active_city_count", i))
	return total


func _rival_cash_total(players: Array, active_player_index: int) -> int:
	var total := 0
	for i in range(players.size()):
		if i == active_player_index:
			continue
		var player := players[i] as Dictionary
		total += int(player.get("cash", 0))
	return total


func _ai_player_count(players: Array) -> int:
	var total := 0
	for player_variant in players:
		var player := player_variant as Dictionary
		if bool(player.get("is_ai", false)) or String(player.get("seat_type", "")) == "ai":
			total += 1
	return total


func _ai_decision_sample_count(players: Array) -> int:
	var total := 0
	for player_variant in players:
		var player := player_variant as Dictionary
		if not (bool(player.get("is_ai", false)) or String(player.get("seat_type", "")) == "ai"):
			continue
		var memory := player.get("ai_memory", {}) as Dictionary
		total += _as_array(memory.get("decision_samples", [])).size()
	return total


func _ai_candidates_have_starter_monster(candidates: Array) -> bool:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if String(candidate.get("action", "")) == "出牌" and String(candidate.get("kind", "")) == "monster_card" and int(candidate.get("score", 0)) > 0:
			return true
	return false


func _queue_has_ai_card_entry(queue: Array, player_index: int) -> bool:
	for entry_variant in queue:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("player_index", -1)) != player_index:
			continue
		var skill := entry.get("skill", {}) as Dictionary
		return String(skill.get("kind", "")) == "monster_card" and int(entry.get("ai_utility_score", 0)) > 0 and entry.has("ai_bid_budget")
	return false


func _queue_highest_bid(queue: Array) -> int:
	var highest := 0
	for entry_variant in queue:
		if entry_variant is Dictionary:
			highest = maxi(highest, int((entry_variant as Dictionary).get("tip", 0)))
	return highest


func _ai_memory_has_training_card_sample(players: Array, player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	var memory := player.get("ai_memory", {}) as Dictionary
	var action_counts := memory.get("action_counts", {}) as Dictionary
	if int(action_counts.get("匿名出牌", 0)) <= 0:
		return false
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		if String(sample.get("kind", "")) != "匿名出牌":
			continue
		var state := sample.get("state", {}) as Dictionary
		var candidates := _as_array(sample.get("candidates", []))
		return state.has("cash") and state.has("total_product_flow") and not candidates.is_empty() and sample.has("baseline_cash")
	return false


func _ai_memory_has_finalized_reward(players: Array, player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	var memory := player.get("ai_memory", {}) as Dictionary
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		if String(sample.get("kind", "")) == "匿名出牌" and bool(sample.get("reward_finalized", false)) and sample.has("reward_cash") and sample.has("reward_settlement"):
			return true
	return false


func _ai_memory_learning_value(memory: Dictionary, tag: String) -> Dictionary:
	var values := memory.get("learned_policy_values", {}) as Dictionary
	return values.get(tag, {}) as Dictionary


func _ai_memory_has_positive_learning(memory: Dictionary, tag: String) -> bool:
	var entry := _ai_memory_learning_value(memory, tag)
	return not entry.is_empty() and float(entry.get("value", 0.0)) > 0.0 and int(entry.get("samples", 0)) > 0


func _ai_memory_has_negative_learning(memory: Dictionary, tag: String) -> bool:
	var entry := _ai_memory_learning_value(memory, tag)
	return not entry.is_empty() and float(entry.get("value", 0.0)) < 0.0 and int(entry.get("samples", 0)) > 0


func _ai_memory_has_episode_sample(memory: Dictionary, policy_kind: String, positive: bool) -> bool:
	for sample_variant in _as_array(memory.get("decision_samples", [])):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		if String(sample.get("policy_kind", "")) != policy_kind or not bool(sample.get("episode_reward_finalized", false)):
			continue
		var reward := int(sample.get("episode_reward_score", 0))
		if positive and reward > 0:
			return true
		if not positive and reward < 0:
			return true
	return false


func _verify_ai_online_learning_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	_reset_contract_runtime(main)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 6400
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "需求改造1")]
			players[player_index] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		ok = ok and CITY_FIXTURES.create_city_bool(main, 1, own_index, "AI学习自城")
		ok = ok and CITY_FIXTURES.create_city_bool(main, 2, rival_index, "AI学习竞品城")
		ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水")
		ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料")
		_ai_controller(main).call("_record_ai_decision", 1, "匿名商业", own_index, 100, "学习测试：涨价有效", [], {
			"policy_kind": "price_pump",
			"product": "环晶电池",
			"strategy_intent": "grow_focus",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "strengthen_route",
		})
		_ai_controller(main).call("_record_ai_decision", 1, "匿名出牌", own_index, 100, "学习测试：需求改造有效", [], {
			"policy_kind": "city_demand_shift",
			"product": "环晶电池",
			"strategy_intent": "grow_focus",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "create_demand",
		})
		_ai_controller(main).call("_record_ai_decision", 1, "匿名合约签约", own_index, 100, "学习测试：签约有效", [], {
			"policy_kind": "contract_accept",
			"product": "环晶电池",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "create_demand",
		})
		_ai_controller(main).call("_record_ai_decision", 1, "城市业主推理", rival_index, 100, "学习测试：城市推理有效", [], {
			"policy_kind": "city_owner_guess",
		})
		_ai_controller(main).call("_record_ai_decision", 1, "卡牌归属押注", 83001, 100, "学习测试：卡牌押注有效", [], {
			"policy_kind": "card_owner_guess",
			"product": "环晶电池",
		})
		var rewarded_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		var rewarded_player := rewarded_players[1] as Dictionary
		rewarded_player["cash"] = int(rewarded_player.get("cash", 0)) + 900
		rewarded_players[1] = rewarded_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = rewarded_players
		main.set("business_cycle_count", int(main.get("business_cycle_count")) + 1)
		var finalized := int(_ai_controller(main).call("_finalize_ai_decision_rewards"))
		var players_after_learning := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var learned_memory := (players_after_learning[1] as Dictionary).get("ai_memory", {}) as Dictionary
		var other_memory := (players_after_learning[2] as Dictionary).get("ai_memory", {}) as Dictionary
		var finalized_ok := finalized >= 5
		var updates_ok := int(learned_memory.get("learning_updates", 0)) > 0
		var price_learned_ok := _ai_memory_has_positive_learning(learned_memory, "policy:price_pump")
		var demand_learned_ok := _ai_memory_has_positive_learning(learned_memory, "policy:city_demand_shift")
		var contract_learned_ok := _ai_memory_has_positive_learning(learned_memory, "policy:contract_accept")
		var city_learned_ok := _ai_memory_has_positive_learning(learned_memory, "policy:city_owner_guess")
		var card_learned_ok := _ai_memory_has_positive_learning(learned_memory, "policy:card_owner_guess")
		var isolated_ok := not _ai_memory_has_positive_learning(other_memory, "policy:price_pump")
		var business_learning_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 1, "price_pump", "grow_focus", "strengthen_route", "环晶电池", "匿名商业"))
		var card_play_learning_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 1, "city_demand_shift", "grow_focus", "create_demand", "环晶电池", "匿名出牌"))
		var contract_learning_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 1, "contract_accept", "", "create_demand", "环晶电池", "匿名合约签约"))
		var strategy_learning_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 1, "", "grow_focus", "", "环晶电池", "战略选择"))
		var route_learning_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 1, "", "grow_focus", "create_demand", "环晶电池", "路线规划"))
		var city_candidate := _ai_controller(main).call("_ai_city_guess_owner_candidate", 1, {
			"district_index": rival_index,
			"priority": 120,
			"latest_clue": "环晶电池公开线索",
			"guess": -1,
			"confidence": 0,
		}, 2) as Dictionary
		var saw_city_learning := String(city_candidate.get("policy_kind", "")) == "city_owner_guess" and int(city_candidate.get("learning_bonus", 0)) > 0
		var card_guess_entry := {
			"resolution_id": 83001,
			"queued_order": 83001,
			"player_index": 2,
			"skill": main.call("_make_skill", "城市融资1"),
			"selected_district": rival_index,
			"play_requirement_product": "环晶电池",
			"play_requirement_flow": 1,
			"winning_bid": 120,
			"public_owner_revealed": false,
			"guessers": [],
			"resolved_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
		}
		var history := _as_array(main.get("resolved_card_history")).duplicate(true)
		history.append(card_guess_entry)
		main.set("resolved_card_history", history)
		var card_candidate := _ai_controller(main).call("_ai_card_guess_candidate_for_owner", 1, card_guess_entry, 2) as Dictionary
		var saw_card_guess_learning := String(card_candidate.get("policy_kind", "")) == "card_owner_guess" and int(card_candidate.get("learning_bonus", 0)) > 0
		var learned_state := _runtime_coordinator(main).call("ai_to_save_data") as Dictionary
		var reset_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		var reset_player := reset_players[1] as Dictionary
		var reset_memory := (reset_player.get("ai_memory", {}) as Dictionary).duplicate(true)
		reset_memory["learned_policy_values"] = {}
		reset_memory["learning_updates"] = 0
		reset_player["ai_memory"] = reset_memory
		reset_players[1] = reset_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = reset_players
		var restore_learned_receipt := _runtime_coordinator(main).call("apply_ai_save_data", learned_state) as Dictionary
		var restore_learned_ok := bool(restore_learned_receipt.get("applied", false))
		var restored_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var restored_memory := (restored_players[1] as Dictionary).get("ai_memory", {}) as Dictionary
		var persisted_ok := _ai_memory_has_positive_learning(restored_memory, "policy:price_pump")
		ok = ok and finalized_ok and updates_ok and price_learned_ok and demand_learned_ok and contract_learned_ok and city_learned_ok and card_learned_ok and isolated_ok
		ok = ok and business_learning_bonus > 0 and card_play_learning_bonus > 0 and contract_learning_bonus > 0 and strategy_learning_bonus > 0 and route_learning_bonus > 0 and saw_city_learning and saw_card_guess_learning
		ok = ok and restore_learned_ok and persisted_ok
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _verify_ai_episode_learning_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	_reset_contract_runtime(main)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 700
			player["action_cooldown"] = 0.0
			if player_index == 1 or player_index == 2:
				var memory := (player.get("ai_memory", {}) as Dictionary).duplicate(true)
				memory["decision_samples"] = []
				memory["learned_policy_values"] = {}
				memory["learning_updates"] = 0
				memory["learning_last_reward"] = 0
				memory["learning_last_tags"] = []
				memory["episode_learning_updates"] = 0
				memory["episode_last_reward"] = 0
				memory["episode_last_top_n_gdp"] = 0
				memory["episode_last_controlled_regions"] = 0
				memory["episode_last_rank"] = -1
				memory["episode_last_result"] = ""
				player["ai_memory"] = memory
			players[player_index] = player
		if players.size() > 0:
			var human_player := players[0] as Dictionary
			human_player["cash"] = 500
			players[0] = human_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		_ai_controller(main).call("_record_ai_decision", 1, "匿名商业", own_index, 180, "终局学习测试：成长路线赚到钱", [], {
			"policy_kind": "price_pump",
			"product": "环晶电池",
			"strategy_intent": "grow_focus",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "strengthen_route",
		})
		_ai_controller(main).call("_record_ai_decision", 2, "匿名商业", rival_index, 120, "终局学习测试：破坏路线亏钱", [], {
			"policy_kind": "route_sabotage",
			"product": "星尘香料",
			"strategy_intent": "disrupt_competitors",
			"route_plan_product": "星尘香料",
			"route_plan_stage": "attack_rival",
		})
		var receipt := {
			"outcome_id": "smoke.victory.learning.1",
			"schema_version": 1,
			"ruleset_id": "v0.5",
			"reason_code": "public_audit_complete",
			"winner_player_indices": [1],
			"co_victory": false,
			"comparison_order": ["top_n_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"],
			"rankings": [
				{"player_index": 1, "top_n_gdp_per_minute": 180, "controlled_region_count": 5, "cash_ledger_cents": 1200000, "winner": true},
				{"player_index": 0, "top_n_gdp_per_minute": 90, "controlled_region_count": 3, "cash_ledger_cents": 50000, "winner": false},
				{"player_index": 2, "top_n_gdp_per_minute": 0, "controlled_region_count": 0, "cash_ledger_cents": 12000, "winner": false},
			],
			"visibility_scope": "public",
		}
		var finalized_updates := int(_ai_controller(main).call("finalize_victory_outcome_learning", receipt))
		var players_after_finish := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var win_memory := (players_after_finish[1] as Dictionary).get("ai_memory", {}) as Dictionary
		var lose_memory := (players_after_finish[2] as Dictionary).get("ai_memory", {}) as Dictionary
		var duplicate_updates := int(_ai_controller(main).call("finalize_victory_outcome_learning", receipt))
		var win_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 1, "price_pump", "grow_focus", "strengthen_route", "环晶电池", "匿名商业"))
		var lose_bonus := int(_ai_controller(main).call("_ai_learning_bonus", 2, "route_sabotage", "disrupt_competitors", "attack_rival", "星尘香料", "匿名商业"))
		ok = ok and finalized_updates == 2
		ok = ok and int(win_memory.get("episode_learning_updates", 0)) > 0
		ok = ok and int(win_memory.get("episode_last_rank", -1)) == 0
		ok = ok and int(win_memory.get("episode_last_top_n_gdp", 0)) == 180
		ok = ok and int(win_memory.get("episode_last_controlled_regions", 0)) == 5
		ok = ok and String(win_memory.get("episode_last_result", "")) == "胜利"
		ok = ok and _ai_memory_has_episode_sample(win_memory, "price_pump", true)
		ok = ok and _ai_memory_has_positive_learning(win_memory, "policy:price_pump")
		ok = ok and _ai_memory_has_positive_learning(win_memory, "strategy:grow_focus")
		ok = ok and win_bonus > 0
		ok = ok and int(lose_memory.get("episode_learning_updates", 0)) > 0
		ok = ok and int(lose_memory.get("episode_last_rank", -1)) > 0
		ok = ok and int(lose_memory.get("episode_last_top_n_gdp", -1)) == 0
		ok = ok and int(lose_memory.get("episode_last_controlled_regions", -1)) == 0
		ok = ok and String(lose_memory.get("episode_last_result", "")) == "未获胜"
		ok = ok and _ai_memory_has_episode_sample(lose_memory, "route_sabotage", false)
		ok = ok and _ai_memory_has_negative_learning(lose_memory, "policy:route_sabotage")
		ok = ok and lose_bonus < 0
		ok = ok and duplicate_updates == 0
		var learned_state := _runtime_coordinator(main).call("ai_to_save_data") as Dictionary
		var reset_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
		var reset_player := reset_players[1] as Dictionary
		var reset_memory := (reset_player.get("ai_memory", {}) as Dictionary).duplicate(true)
		reset_memory["learned_policy_values"] = {}
		reset_memory["episode_learning_updates"] = 0
		reset_player["ai_memory"] = reset_memory
		reset_players[1] = reset_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = reset_players
		var restore_learned_receipt := _runtime_coordinator(main).call("apply_ai_save_data", learned_state) as Dictionary
		ok = ok and bool(restore_learned_receipt.get("applied", false))
		var restored_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var restored_memory := (restored_players[1] as Dictionary).get("ai_memory", {}) as Dictionary
		ok = ok and _ai_memory_has_positive_learning(restored_memory, "policy:price_pump")
		ok = ok and int(restored_memory.get("episode_learning_updates", 0)) > 0
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _first_rival_city_index(main: Node, active_player_index: int) -> int:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	for i in range(districts.size()):
		var district := districts[i] as Dictionary
		var city := district.get("city", {}) as Dictionary
		if city.is_empty():
			continue
		if not bool(city.get("active", true)):
			continue
		if int(city.get("owner", -1)) != active_player_index:
			return i
	return -1


func _city_markers_include_unknown_rival(main: Node) -> bool:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var viewer_index := coordinator.presentation_authorized_viewer_index() if coordinator != null else -1
	var projection := coordinator.presentation_public_map_projection(viewer_index) if coordinator != null else TablePublicMapProjection.new()
	for marker_variant in projection.city_markers:
		var marker := marker_variant as Dictionary
		if String(marker.get("tag", "")) == "?":
			return true
	return false


func _city_public_clue_exists(main: Node) -> bool:
	for district_variant in _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts):
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		if String(city.get("last_public_clue", "")) != "":
			return true
	return false


func _city_public_clue_history_exists(main: Node) -> bool:
	for district_variant in _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts):
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		var clues := _as_array(city.get("public_clues", []))
		for clue_variant in clues:
			if clue_variant is Dictionary:
				var clue_entry := clue_variant as Dictionary
				var text := String(clue_entry.get("text", ""))
				var kind := String(clue_entry.get("kind", ""))
				var products := _as_array(clue_entry.get("products", []))
				if text != "" and kind != "" and float(clue_entry.get("time", -1.0)) >= 0.0 and not products.is_empty():
					return true
				continue
			var clue := String(clue_variant)
			if clue.contains("匿名") or clue.contains("周期") or clue.contains("合约"):
				return true
	return false


func _product_market_controller_for_test(main: Node) -> Node:
	return main.get_node_or_null(PRODUCT_MARKET_CONTROLLER_NODE_PATH)


func _product_market_for_test(main: Node) -> Dictionary:
	var controller := _product_market_controller_for_test(main)
	if controller == null or not controller.has_method("runtime_state_snapshot"):
		return {}
	var snapshot_variant: Variant = controller.call("runtime_state_snapshot")
	if not (snapshot_variant is Dictionary):
		return {}
	var market_variant: Variant = (snapshot_variant as Dictionary).get("product_market", {})
	return (market_variant as Dictionary).duplicate(true) if market_variant is Dictionary else {}


func _replace_product_market_for_test(main: Node, market: Dictionary) -> bool:
	var controller := _product_market_controller_for_test(main)
	if controller == null or not controller.has_method("to_save_data") or not controller.has_method("apply_save_data"):
		return false
	var save_variant: Variant = controller.call("to_save_data")
	if not (save_variant is Dictionary):
		return false
	var save_data := (save_variant as Dictionary).duplicate(true)
	save_data["product_market"] = market.duplicate(true)
	var applied_variant: Variant = controller.call("apply_save_data", save_data)
	return applied_variant is Dictionary and (applied_variant as Dictionary).get("product_market", {}) is Dictionary


func _product_market_has_prices(product_market: Dictionary) -> bool:
	for entry_variant in product_market.values():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("price", 0)) > 0 and int(entry.get("base_price", 0)) > 0:
			return true
	return false


func _product_market_float(product_market: Dictionary, product_name: String, field_name: String) -> float:
	var entry := product_market.get(product_name, {}) as Dictionary
	return float(entry.get(field_name, 1.0))


func _player_has_card_family(card_names: Array, target_name: String) -> bool:
	var target_family := _skill_family(target_name)
	for name_variant in card_names:
		if _skill_family(String(name_variant)) == target_family:
			return true
	return false


func _container_button_text_contains(container: Node, needle: String) -> bool:
	for child in container.get_children():
		if child is Button and String((child as Button).text).contains(needle):
			return true
		if child is Node and _container_button_text_contains(child, needle):
			return true
	return false


func _first_control_child(container: Node) -> Control:
	if container == null:
		return null
	for child in container.get_children():
		if child is Control:
			return child as Control
	return null


func _container_label_text_contains(container: Node, needle: String) -> bool:
	for child in container.get_children():
		if child is Label and String((child as Label).text).contains(needle):
			return true
		if child is Node and _container_label_text_contains(child, needle):
			return true
	return false


func _container_button_tooltip_contains(container: Node, needle: String) -> bool:
	for child in container.get_children():
		if child is Button and String((child as Button).tooltip_text).contains(needle):
			return true
		if child is Node and _container_button_tooltip_contains(child, needle):
			return true
	return false


func _container_control_tooltip_contains(container: Node, needle: String) -> bool:
	if container is Control and String((container as Control).tooltip_text).contains(needle):
		return true
	for child in container.get_children():
		if child is Node and _container_control_tooltip_contains(child, needle):
			return true
	return false


func _runtime_split_table_text_or_tooltip_contains(main: Node, needle: String) -> bool:
	var runtime_screen := main.get("runtime_game_screen") as Control
	if runtime_screen == null:
		return false
	return _container_label_text_contains(runtime_screen, needle) \
		or _container_button_text_contains(runtime_screen, needle) \
		or _container_control_tooltip_contains(runtime_screen, needle)


func _expect_runtime_map_focus_target(main: Node, district_index: int, label: String) -> void:
	var map_node := main.get("map_view") as Node
	if map_node == null or not map_node.has_method("get_projection_debug_snapshot"):
		_expect(false, "%s has a runtime MapView snapshot" % label)
		return
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		_expect(false, "%s has a valid target district" % label)
		return
	var snapshot_variant: Variant = map_node.call("get_projection_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var target: Vector2 = (districts[district_index] as Dictionary).get("center", Vector2.ZERO)
	var focus_target: Vector2 = snapshot.get("focus_target_center_m", Vector2(-999999.0, -999999.0))
	_expect(int(snapshot.get("focus_target_district", -1)) == district_index, "%s records the target region" % label)
	_expect(focus_target.distance_to(target) <= 1.0, "%s records the region center for planet rotation" % label)


func _public_track_root(main: Node) -> Control:
	var legacy_track := main.get("card_resolution_track") as Control
	if legacy_track != null:
		return legacy_track
	var runtime_screen := main.get("runtime_game_screen") as Control
	if runtime_screen == null:
		return null
	var split_track := runtime_screen.find_child("PublicTrack", true, false) as Control
	if split_track == null:
		split_track = runtime_screen.find_child("CardTrack", true, false) as Control
	return split_track


func _public_track_row(main: Node) -> Node:
	var legacy_track := main.get("card_resolution_track") as Node
	if legacy_track != null:
		return legacy_track
	var root := _public_track_root(main)
	if root == null:
		return null
	var row := root.find_child("CardTrackRow", true, false)
	return row if row != null else root


func _public_track_scroll(main: Node) -> ScrollContainer:
	var legacy_scroll := main.get("card_resolution_track_scroll") as ScrollContainer
	if legacy_scroll != null:
		return legacy_scroll
	var root := _public_track_root(main)
	if root == null:
		return null
	return root.find_child("CardTrackScroll", true, false) as ScrollContainer


func _public_track_text_contains(main: Node, needle: String) -> bool:
	var row := _public_track_row(main)
	return (row != null and (_container_label_text_contains(row, needle) or _container_button_text_contains(row, needle))) \
		or _public_track_snapshot_text_contains(main, needle)


func _public_track_tooltip_contains(main: Node, needle: String) -> bool:
	var row := _public_track_row(main)
	return (row != null and (_container_button_tooltip_contains(row, needle) or _container_control_tooltip_contains(row, needle))) \
		or _public_track_snapshot_text_contains(main, needle)


func _public_track_child_count(main: Node) -> int:
	var row := _public_track_row(main)
	return row.get_child_count() if row != null else 0


func _public_track_snapshot_text_contains(main: Node, needle: String) -> bool:
	if not main.has_method("_runtime_table_snapshot"):
		return false
	var snapshot_variant: Variant = main.call("_runtime_table_snapshot")
	if not (snapshot_variant is Dictionary):
		return false
	var snapshot: Dictionary = snapshot_variant
	var entries: Array = snapshot.get("card_track", []) if snapshot.get("card_track", []) is Array else []
	return var_to_str(entries).contains(needle)


func _public_track_content_width(row: Node) -> float:
	if row == null:
		return 0.0
	var width := 0.0
	var child_count := 0
	for child in row.get_children():
		if child is Control:
			var control := child as Control
			width += maxf(control.custom_minimum_size.x, control.get_combined_minimum_size().x)
			child_count += 1
	if child_count > 1 and row is Container:
		width += float(child_count - 1) * float((row as Container).get_theme_constant("separation"))
	return maxf(width, row.get_combined_minimum_size().x if row is Control else width)


func _public_track_max_scroll(main: Node) -> int:
	if main.get("card_resolution_track_scroll") != null and main.has_method("_card_resolution_track_max_scroll"):
		var legacy_max := int(main.call("_card_resolution_track_max_scroll"))
		if legacy_max > 0:
			return legacy_max
	var scroll := _public_track_scroll(main)
	var row := _public_track_row(main)
	if scroll == null or row == null:
		return 0
	var viewport_width := maxf(1.0, scroll.size.x)
	return maxi(0, int(ceil(_public_track_content_width(row) - viewport_width)))


func _set_public_track_scroll(main: Node, amount: int) -> int:
	if main.get("card_resolution_track_scroll") != null and main.has_method("_set_card_resolution_track_scroll"):
		return int(main.call("_set_card_resolution_track_scroll", amount))
	var scroll := _public_track_scroll(main)
	if scroll == null:
		return 0
	var clamped := clampi(amount, 0, _public_track_max_scroll(main))
	scroll.scroll_horizontal = clamped
	return clamped


func _scroll_public_track_by(main: Node, delta_pixels: int) -> int:
	if main.get("card_resolution_track_scroll") != null and main.has_method("_scroll_card_resolution_track_by"):
		return int(main.call("_scroll_card_resolution_track_by", delta_pixels))
	var scroll := _public_track_scroll(main)
	return _set_public_track_scroll(main, int(scroll.scroll_horizontal) + delta_pixels) if scroll != null else 0


func _container_button_has_stylebox(container: Node, style_name: String) -> bool:
	for child in container.get_children():
		if child is Button and (child as Button).has_theme_stylebox_override(style_name):
			return true
		if child is Node and _container_button_has_stylebox(child, style_name):
			return true
	return false


func _container_has_meta(container: Node, meta_name: String) -> bool:
	if container.has_meta(meta_name):
		return true
	for child in container.get_children():
		if child is Node and _container_has_meta(child, meta_name):
			return true
	return false


func _menu_overlay_node(main: Node, node_name: String) -> Node:
	var overlay := main.get("menu_overlay") as Node
	if overlay == null:
		return null
	return overlay.find_child(node_name, true, false)


func _container_has_named_node(container: Node, node_name: String) -> bool:
	if String(container.name) == node_name:
		return true
	for child in container.get_children():
		if child is Node and _container_has_named_node(child, node_name):
			return true
	return false


func _container_card_art_kind_contains(container: Node, kind: String) -> bool:
	for child in container.get_children():
		if child.has_method("set_card") and str(child.get("card_kind")) == kind:
			return true
		if child is Node and _container_card_art_kind_contains(child, kind):
			return true
	return false


func _container_card_art_stats_contains(container: Node, needle: String) -> bool:
	for child in container.get_children():
		if child.has_method("set_card") and str(child.get("card_stats")).contains(needle):
			return true
		if child is Node and _container_card_art_stats_contains(child, needle):
			return true
	return false


func _skill_family(skill_name: String) -> String:
	var end := skill_name.length()
	while end > 0 and "0123456789".contains(skill_name.substr(end - 1, 1)):
		end -= 1
	return skill_name.substr(0, end)


func _skill_rank(skill_name: String) -> int:
	var digits := ""
	var index := skill_name.length() - 1
	while index >= 0:
		var ch := skill_name.substr(index, 1)
		if not "0123456789".contains(ch):
			break
		digits = ch + digits
		index -= 1
	return int(digits) if digits != "" else 0


func _runtime_card_coordinator(main: Node) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null


func _card_presentation_category_id(main: Node, skill: Dictionary) -> String:
	var coordinator := _runtime_card_coordinator(main)
	if coordinator == null or not coordinator.has_method("compose_card_presentation"):
		return ""
	var source := {"card_name": str(skill.get("name", "")), "skill": skill}
	var presentation := coordinator.call("compose_card_presentation", source) as Dictionary
	return str(presentation.get("category_id", ""))


func _execute_ai_v06_facility_bootstrap_smoke(main: Node) -> Dictionary:
	var result := {
		"acted": 0,
		"sources_before": 0,
		"sources_after": 0,
		"cash_before": 0,
		"cash_after": 0,
		"human_source_after": false,
		"public_available": false,
	}
	var coordinator := _runtime_card_coordinator(main)
	var ai := _ai_controller(main)
	if coordinator == null or ai == null \
			or not coordinator.has_method("refresh_v06_production_player_bindings") \
			or not ai.has_method("execute_v06_facility_bootstrap_cycle"):
		return result
	coordinator.call("refresh_v06_production_player_bindings", main)
	var player_count := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).size()
	var before := _ai_v06_economy_summary(coordinator, player_count)
	var previous_enabled := bool(ai.get("ai_card_decision_enabled"))
	ai.set("ai_card_decision_enabled", true)
	var acted := 0
	for _cycle in range(maxi(1, player_count * 2)):
		var receipt_variant: Variant = ai.call("execute_v06_facility_bootstrap_cycle", true)
		var receipt: Dictionary = (receipt_variant as Dictionary).duplicate(true) if receipt_variant is Dictionary else {}
		acted += int(receipt.get("acted", 0))
		if int(receipt.get("acted", 0)) <= 0 and int(receipt.get("attempted", 0)) <= 0:
			break
	ai.set("ai_card_decision_enabled", previous_enabled)
	var after := _ai_v06_economy_summary(coordinator, player_count)
	var public_snapshot: Dictionary = ai.call("ai_v06_facility_bootstrap_public_snapshot") if ai.has_method("ai_v06_facility_bootstrap_public_snapshot") else {}
	result["acted"] = acted
	result["sources_before"] = int(before.get("source_count", 0))
	result["sources_after"] = int(after.get("source_count", 0))
	result["cash_before"] = int(before.get("cash", 0))
	result["cash_after"] = int(after.get("cash", 0))
	result["human_source_after"] = bool(after.get("human_source", false))
	result["public_available"] = bool(public_snapshot.get("available", false))
	return result


func _ai_v06_economy_summary(coordinator: Node, player_count: int) -> Dictionary:
	var source_count := 0
	var cash := 0
	var human_source := false
	for player_index in range(player_count):
		var binding_variant: Variant = coordinator.call("actor_id_for_player_index", player_index) if coordinator.has_method("actor_id_for_player_index") else {}
		var binding: Dictionary = (binding_variant as Dictionary).duplicate(true) if binding_variant is Dictionary else {}
		if not bool(binding.get("available", false)):
			continue
		var actor_id := String(binding.get("actor_id", "")).strip_edges()
		var source_variant: Variant = coordinator.call("economic_source_snapshot", actor_id) if coordinator.has_method("economic_source_snapshot") else {}
		var source: Dictionary = (source_variant as Dictionary).duplicate(true) if source_variant is Dictionary else {}
		var player_variant: Variant = coordinator.call("player_snapshot", actor_id) if coordinator.has_method("player_snapshot") else {}
		var player: Dictionary = (player_variant as Dictionary).duplicate(true) if player_variant is Dictionary else {}
		if player_index == 0:
			human_source = bool(source.get("has_source", false))
			continue
		cash += int(player.get("cash", 0))
		if bool(source.get("has_source", false)) and bool(source.get("bootstrap_finalized", false)):
			source_count += 1
	return {
		"source_count": source_count,
		"cash": cash,
		"human_source": human_source,
	}


func _runtime_card_exists(main: Node, card_id: String) -> bool:
	var coordinator := _runtime_card_coordinator(main)
	return bool(coordinator.call("card_exists", card_id)) if coordinator != null else false


func _runtime_card_definition(main: Node, card_id: String) -> Dictionary:
	var coordinator := _runtime_card_coordinator(main)
	var value: Variant = coordinator.call("card_definition", card_id) if coordinator != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_presentation_snapshot(main: Node, skill: Dictionary, card_name: String = "") -> Dictionary:
	var source_service := _card_codex_public_source_service(main)
	if source_service == null or not source_service.has_method("compose_card_facts"):
		return {}
	var resolved_name := card_name if card_name != "" else str(skill.get("name", ""))
	if resolved_name == "":
		return {}
	var value: Variant = source_service.call("compose_card_facts", resolved_name, -1)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_presentation_text(main: Node, skill: Dictionary, field: String, card_name: String = "") -> String:
	return str(_card_presentation_snapshot(main, skill, card_name).get(field, ""))


func _card_presentation_array(main: Node, skill: Dictionary, field: String, card_name: String = "") -> Array:
	var value: Variant = _card_presentation_snapshot(main, skill, card_name).get(field, [])
	return (value as Array).duplicate(true) if value is Array else []


func _card_codex_public_source_service(main: Node) -> Node:
	var coordinator := _runtime_card_coordinator(main)
	return coordinator.get_node_or_null("CardCodexPublicSourceService") if coordinator != null else null


func _clear_player_cooldown(main: Node, player_index: int) -> void:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	if player_index < 0 or player_index >= players.size():
		return
	var player := players[player_index] as Dictionary
	player["action_cooldown"] = 0.0
	players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _verify_card_resolution_v06_owner_contracts(main: Node) -> Dictionary:
	var result := {
		"cadence": false,
		"submission_limits": false,
		"rotating_order": false,
		"public_snapshot_safe": false,
		"lifecycle": false,
		"owner_boundary": false,
	}
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if coordinator == null or not coordinator.has_method("card_group_runtime_rules"):
		return result
	var rules: Dictionary = coordinator.call("card_group_runtime_rules")
	result["cadence"] = int(rules.get("group_seconds", 0)) == 30 \
		and int(rules.get("planning_seconds", 0)) == 20 \
		and int(rules.get("public_bid_seconds", 0)) == 5 \
		and int(rules.get("lock_seconds", 0)) == 5 \
		and int(rules.get("opening_extended_windows", 0)) == 3 \
		and int(rules.get("opening_group_seconds", 0)) == 45 \
		and int(rules.get("opening_planning_seconds", 0)) == 35
	var queue := CARD_RESOLUTION_QUEUE_SCRIPT.new()
	root.add_child(queue)
	queue.configure({"ruleset_id": "v0.6", "card_group": rules})
	var planning_facts := {
		"player_count": EXPECTED_PLAYER_COUNT,
		"batch_locked": false,
		"counter_window_active": false,
		"simultaneous_timer": 45.0,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"window_sequence": 0,
		"reference_player": 0,
	}
	var committed_all := true
	for player_index in range(3):
		var request := {
			"player_index": player_index,
			"slot_index": player_index,
			"already_queued": false,
			"play_cash_cost_cents": 0,
			"financial_margin_cents": 0,
			"available_cash_cents": 100000,
			"skill": {"name": "smoke.card.%d" % player_index, "kind": "qa", "persistent": true},
		}
		var plan: Dictionary = queue.plan_submission(request, planning_facts)
		var committed: Dictionary = queue.commit_submission(plan, {
			"authorized": true,
			"inventory_committed": true,
			"play_cost_authorized": true,
			"financial_margin_authorized": true,
			"asset_authorized": true,
		}) if bool(plan.get("accepted", false)) else {}
		committed_all = committed_all and bool(committed.get("committed", false))
	var duplicate_request := {
		"player_index": 0,
		"slot_index": 99,
		"already_queued": false,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"available_cash_cents": 100000,
		"skill": {"name": "smoke.duplicate", "kind": "qa", "persistent": true},
	}
	var duplicate_plan: Dictionary = queue.plan_submission(duplicate_request, planning_facts)
	var public_phase_facts := planning_facts.duplicate(true)
	public_phase_facts["simultaneous_timer"] = 10.0
	var public_phase_request := duplicate_request.duplicate(true)
	public_phase_request["player_index"] = 3
	var public_phase_plan: Dictionary = queue.plan_submission(public_phase_request, public_phase_facts)
	result["submission_limits"] = committed_all \
		and str(duplicate_plan.get("reason", "")) == "group_full" \
		and str(public_phase_plan.get("reason", "")) == "public_bid_phase"
	var current: Array = queue.current_queue()
	var player_order: Array = []
	for entry_variant in current:
		if entry_variant is Dictionary:
			player_order.append(int((entry_variant as Dictionary).get("player_index", -1)))
	result["rotating_order"] = player_order == [1, 2, 0]
	var public_snapshot: Dictionary = queue.public_snapshot()
	var public_text := JSON.stringify(public_snapshot)
	result["public_snapshot_safe"] = int(public_snapshot.get("current_count", 0)) == 3 \
		and not public_text.contains("player_index") \
		and not public_text.contains("priority_bid") \
		and not public_text.contains("bid_budget") \
		and not public_text.contains("cash")
	var locked: Dictionary = queue.lock_batch({"reference_player": 0, "player_count": EXPECTED_PLAYER_COUNT})
	var started: Dictionary = queue.start_next({"game_time": 0.0})
	var active: Dictionary = started.get("active_entry", {}) if started.get("active_entry", {}) is Dictionary else {}
	var active_id := int(active.get("resolution_id", -1))
	var completed: Dictionary = queue.complete_active(active_id, {})
	result["lifecycle"] = bool(locked.get("locked", false)) \
		and bool(started.get("started", false)) \
		and active_id > 0 \
		and bool(completed.get("completed", false)) \
		and queue.active_entry().is_empty()
	var debug: Dictionary = queue.debug_snapshot()
	result["owner_boundary"] = not bool(debug.get("priority_bid_authority", true)) \
		and not bool(debug.get("cash_authority", true)) \
		and not bool(debug.get("inventory_authority", true))
	queue.free()
	return result


func _set_player_skill(main: Node, player_index: int, slot_index: int, skill_name: String) -> void:
	var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	if player_index < 0 or player_index >= players.size():
		return
	var player := players[player_index] as Dictionary
	var slots := _as_array(player.get("slots", []))
	while slots.size() <= slot_index:
		slots.append(null)
	var skill := main.call("_make_skill", skill_name) as Dictionary
	# These injected cards isolate effect behavior; play-requirement coverage has its own cases.
	skill["starter_play_free"] = true
	slots[slot_index] = skill
	player["slots"] = slots
	players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _city_product_level(city: Dictionary, product_name: String) -> int:
	for product_variant in _as_array(city.get("products", [])):
		var product := product_variant as Dictionary
		if String(product.get("name", "")) == product_name:
			return int(product.get("level", 0))
	return 0


func _city_has_product(city: Dictionary, product_name: String) -> bool:
	for product_variant in _as_array(city.get("products", [])):
		var product := product_variant as Dictionary
		if String(product.get("name", "")) == product_name:
			return true
	return false


func _as_string_array(items: Array) -> Array:
	var result := []
	for item_variant in items:
		result.append(String(item_variant))
	return result


func _verify_card_play_flow_gate_and_one_shot(main: Node, district_index: int) -> bool:
	var previous_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	var previous_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var previous_log_lines := _public_log_messages(main).duplicate(true)
	var previous_callouts := _visual_cue_array(main, "action_callouts").duplicate(true)
	var previous_selected_player := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player)
	var previous_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var previous_selected_trade_product := String(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product)
	if district_index < 0 or district_index >= previous_districts.size() or previous_players.is_empty():
		return false
	var district := previous_districts[district_index] as Dictionary
	var city := district.get("city", {}) as Dictionary
	if int(city.get("owner", -1)) != 0 or not bool(city.get("active", false)):
		return false
	var products := _as_array(city.get("products", []))
	if products.is_empty():
		return false
	var product_name := String((products[0] as Dictionary).get("name", ""))
	if product_name == "":
		return false
	var flow_before := int(main.call("_player_product_flow", 0, product_name))
	if flow_before <= 0:
		return false
	var product_level_before := _city_product_level(city, product_name)
	var slot_index := 8
	var players := previous_players.duplicate(true)
	var player := players[0] as Dictionary
	var slots := _as_array(player.get("slots", [])).duplicate(true)
	while slots.size() <= slot_index:
		slots.append(null)
	var playable_skill := main.call("_make_skill", "轨道融资1") as Dictionary
	playable_skill.erase("starter_play_free")
	playable_skill["persistent"] = false
	slots[slot_index] = playable_skill
	player["slots"] = slots
	players[0] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = product_name
	_clear_player_cooldown(main, 0)
	var cash_before := _player_cash(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0)
	var playable_evaluation := main.call("_card_play_eligibility_snapshot", 0, playable_skill, "rule", {}) as Dictionary
	var can_play := bool(playable_evaluation.get("allowed", false))
	var requirement_text := String((playable_evaluation.get("requirement_status", {}) as Dictionary).get("requirement_text", ""))
	main.call("_use_skill", slot_index)
	var players_after_play := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var player_after_play := players_after_play[0] as Dictionary
	var slots_after_play := _as_array(player_after_play.get("slots", []))
	var districts_after_play := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var city_after_play := (districts_after_play[district_index] as Dictionary).get("city", {}) as Dictionary
	var play_ok := can_play \
		and requirement_text.contains("条件：无") \
		and _player_cash(players_after_play, 0) > cash_before \
		and slot_index < slots_after_play.size() \
		and slots_after_play[slot_index] == null \
		and int(main.call("_player_product_flow", 0, product_name)) == flow_before \
		and _city_product_level(city_after_play, product_name) == product_level_before
	_clear_player_cooldown(main, 0)
	players_after_play = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	player_after_play = players_after_play[0] as Dictionary
	slots_after_play = _as_array(player_after_play.get("slots", [])).duplicate(true)
	var blocked_skill := main.call("_make_skill", "城市融资2") as Dictionary
	blocked_skill.erase("starter_play_free")
	blocked_skill["play_requirement_kind"] = "region_gdp_share"
	blocked_skill["play_region_scope"] = "target_region"
	blocked_skill["play_region_gdp_share_required"] = 15
	var blocked_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var blocked_district := blocked_districts[district_index] as Dictionary
	var blocked_city := (blocked_district.get("city", {}) as Dictionary).duplicate(true)
	blocked_city["owner"] = 1
	blocked_city["projects"] = []
	blocked_district["city"] = blocked_city
	blocked_districts[district_index] = blocked_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = blocked_districts
	blocked_skill["persistent"] = false
	slots_after_play[slot_index] = blocked_skill
	player_after_play["slots"] = slots_after_play
	players_after_play[0] = player_after_play
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players_after_play
	var cash_before_blocked := _player_cash(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players), 0)
	var blocked_can_play := bool((main.call("_card_play_eligibility_snapshot", 0, blocked_skill, "rule", {}) as Dictionary).get("allowed", false))
	main.call("_use_skill", slot_index)
	var players_after_blocked := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var blocked_player := players_after_blocked[0] as Dictionary
	var blocked_slots := _as_array(blocked_player.get("slots", []))
	var blocked_ok := not blocked_can_play \
		and slot_index < blocked_slots.size() \
		and blocked_slots[slot_index] != null \
		and String((blocked_slots[slot_index] as Dictionary).get("name", "")) == String(blocked_skill.get("name", "")) \
		and _player_cash(players_after_blocked, 0) == cash_before_blocked
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = previous_players
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = previous_districts
	_replace_public_log_messages(main, previous_log_lines)
	_set_visual_cue_array(main, "action_callouts", previous_callouts)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = previous_selected_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = previous_selected_trade_product
	main.call("_refresh_ui")
	return play_ok and blocked_ok


func _verify_realtime_gdp_directionality_pack(main: Node, district_index: int) -> bool:
	var previous_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var previous_market := _product_market_for_test(main)
	var previous_selected_district := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	var previous_selected_product := String(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product)
	var previous_log_lines := _public_log_messages(main).duplicate(true)
	var ok := true
	var districts := previous_districts.duplicate(true)
	if district_index < 0 or district_index >= districts.size() or districts.size() < 2:
		ok = false
	else:
		var source_index := (district_index + 1) % districts.size()
		if source_index == district_index:
			ok = false
		else:
			var product_name := "烟测方向商品"
			var target := (districts[district_index] as Dictionary).duplicate(true)
			var source := (districts[source_index] as Dictionary).duplicate(true)
			var target_neighbors := _as_array(target.get("neighbors", [])).duplicate(true)
			var source_neighbors := _as_array(source.get("neighbors", [])).duplicate(true)
			if not target_neighbors.has(source_index):
				target_neighbors.append(source_index)
			if not source_neighbors.has(district_index):
				source_neighbors.append(district_index)
			target["neighbors"] = target_neighbors
			source["neighbors"] = source_neighbors
			target["terrain"] = "land"
			source["terrain"] = "land"
			target["destroyed"] = false
			source["destroyed"] = false
			target["products"] = []
			source["products"] = [product_name]
			target["production_level"] = 2
			target["transport_level"] = 2
			target["consumption_level"] = 2
			target["damage"] = 0
			source["production_level"] = 4
			source["transport_level"] = 3
			source["consumption_level"] = 1
			target.erase("transport_score")
			source.erase("transport_score")
			target["city"] = {
				"active": true,
				"owner": 0,
				"products": [{"name": product_name, "level": 1}],
				"demands": [product_name],
				"revenue_bonus": 0,
				"contract_income_bonus": 0,
				"contract_seconds": 0.0,
				"contract_turns": 0,
				"trade_route_damage": 0,
				"trade_disrupted_routes": 0,
				"competition_matches": 0,
				"route_flow_multiplier": 1.0,
				"route_flow_seconds": 0.0,
				"route_flow_turns": 0,
				"route_flow_source": "",
				"cashflow_remainder": 0.0,
			}
			source["city"] = {}
			districts[district_index] = target
			districts[source_index] = source
			var product_market := previous_market.duplicate(true)
			product_market[product_name] = {
				"price": 100,
				"base_price": 100,
				"tier": "测试",
				"supply": 4,
				"demand": 4,
				"volatility": 1,
				"temporary_supply_pressure": 0,
				"temporary_demand_pressure": 0,
			}
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			_replace_product_market_for_test(main, product_market)
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = product_name
			main.call("_refresh_city_networks")
			var baseline := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			var baseline_product := int(baseline.get("product", 0))
			var baseline_route := int(baseline.get("route", 0))
			var baseline_net := int(baseline.get("net", 0))
			ok = ok and baseline_product > 0 and baseline_route > 0 and baseline_net > 0

			districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			target = (districts[district_index] as Dictionary).duplicate(true)
			target["production_level"] = 5
			target.erase("transport_score")
			districts[district_index] = target
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			main.call("_refresh_city_networks")
			var production_breakdown := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			var production_product := int(production_breakdown.get("product", 0))
			ok = ok and production_product > baseline_product

			districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			target = (districts[district_index] as Dictionary).duplicate(true)
			target["transport_level"] = 5
			target.erase("transport_score")
			districts[district_index] = target
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			main.call("_refresh_city_networks")
			var transport_breakdown := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			var transport_product := int(transport_breakdown.get("product", 0))
			ok = ok and transport_product > production_product

			districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			target = (districts[district_index] as Dictionary).duplicate(true)
			target["consumption_level"] = 5
			districts[district_index] = target
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			main.call("_refresh_city_networks")
			var consumption_breakdown := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			var consumption_route := int(consumption_breakdown.get("route", 0))
			ok = ok and consumption_route > int(transport_breakdown.get("route", 0))

			districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			target = (districts[district_index] as Dictionary).duplicate(true)
			var city := (target.get("city", {}) as Dictionary).duplicate(true)
			city["route_flow_multiplier"] = 1.6
			city["route_flow_seconds"] = 120.0
			city["route_flow_turns"] = 4
			city["route_flow_source"] = "烟测流速"
			target["city"] = city
			districts[district_index] = target
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			main.call("_refresh_city_networks")
			var route_flow_breakdown := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			var route_flow_route := int(route_flow_breakdown.get("route", 0))
			var route_flow_net := int(route_flow_breakdown.get("net", 0))
			ok = ok and route_flow_route > consumption_route

			districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			target = (districts[district_index] as Dictionary).duplicate(true)
			city = (target.get("city", {}) as Dictionary).duplicate(true)
			city["trade_route_damage"] = 1
			target["city"] = city
			districts[district_index] = target
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			main.call("_refresh_city_networks")
			var route_damage_breakdown := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			ok = ok and int(route_damage_breakdown.get("route_penalty", 0)) > 0 and int(route_damage_breakdown.get("net", 0)) < route_flow_net

			districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
			target = (districts[district_index] as Dictionary).duplicate(true)
			target["damage"] = 3
			districts[district_index] = target
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
			var region_damage_breakdown := main.call("_city_cycle_income_breakdown", district_index, 0) as Dictionary
			ok = ok and int(region_damage_breakdown.get("damage_penalty", 0)) > int(route_damage_breakdown.get("damage_penalty", 0)) and int(region_damage_breakdown.get("net", 0)) <= int(route_damage_breakdown.get("net", 0))

			var summary := String(main.call("_city_income_breakdown_summary", region_damage_breakdown))
			var reason := String(main.call("_city_gdp_change_reason_text", region_damage_breakdown))
			ok = ok and summary.contains("生产GDP") and summary.contains("消费GDP") and summary.contains("断路") and summary.contains("损伤")
			ok = ok and reason.contains("驱动") and reason.contains("压力")
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = previous_districts
	_replace_product_market_for_test(main, previous_market)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = previous_selected_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = previous_selected_product
	_replace_public_log_messages(main, previous_log_lines)
	main.call("_refresh_ui")
	return ok


func _verify_economy_card_effects(main: Node, district_index: int) -> void:
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = district_index
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var city := (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var products := _as_array(city.get("products", []))
	_expect(not products.is_empty(), "built city has products for economy-card testing")
	if products.is_empty():
		return
	var product_name := String((products[0] as Dictionary).get("name", ""))
	var product_level_before := _city_product_level(city, product_name)
	var revenue_before := int(city.get("revenue_bonus", 0))
	_set_player_skill(main, 0, 2, "产业升级1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(_city_product_level(city, product_name) == product_level_before + 1, "industry upgrade raises the lowest-level city product")
	_expect(int(city.get("revenue_bonus", 0)) == revenue_before + 25, "industry upgrade adds permanent city GDP/min revenue")

	var demands_for_shift := _as_array(city.get("demands", []))
	_expect(not demands_for_shift.is_empty(), "built city has demand products for product-shift testing")
	if not demands_for_shift.is_empty():
		var shift_target := String(demands_for_shift[0])
		var revenue_before_shift := int(city.get("revenue_bonus", 0))
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = shift_target
		_set_player_skill(main, 0, 2, "商品换线1")
		_clear_player_cooldown(main, 0)
		main.call("_use_skill", 2)
		districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
		_expect(_city_has_product(city, shift_target), "product line shift adds the selected trade product to the city")
		_expect(int(city.get("revenue_bonus", 0)) == revenue_before_shift + 18, "product line shift adds permanent city revenue")

	var demands_before_shift := _as_string_array(_as_array(city.get("demands", [])))
	if not demands_before_shift.is_empty():
		city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + 2
		districts[district_index]["city"] = city
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
		var damage_before_demand_shift := int(city.get("trade_route_damage", 0))
		var revenue_before_demand_shift := int(city.get("revenue_bonus", 0))
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = product_name
		_set_player_skill(main, 0, 2, "需求改造1")
		_clear_player_cooldown(main, 0)
		main.call("_use_skill", 2)
		districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
		var demands_after_shift := _as_string_array(_as_array(city.get("demands", [])))
		_expect(demands_after_shift != demands_before_shift, "demand redesign changes at least one city demand product")
		_expect(int(city.get("trade_route_damage", 0)) == damage_before_demand_shift - 1, "demand redesign repairs one route-damage pressure")
		_expect(int(city.get("revenue_bonus", 0)) == revenue_before_demand_shift + 10, "demand redesign adds permanent city revenue")

	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = product_name
	var product_market := _product_market_for_test(main)
	var entry := product_market.get(product_name, {}) as Dictionary
	entry["price"] = int(entry.get("base_price", 60))
	entry["trend"] = 0
	product_market[product_name] = entry
	_replace_product_market_for_test(main, product_market)
	var players_before_pump := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	var card_income_before := int((players_before_pump[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "价格套利1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	var players_after_pump := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	var demand_pressure_after_pump := int(entry.get("temporary_demand_pressure", 0))
	_expect(demand_pressure_after_pump > 0, "price speculation creates temporary demand pressure instead of directly setting price")
	_expect(int((players_after_pump[0] as Dictionary).get("total_card_income", 0)) == card_income_before + 220, "price speculation records card-generated cash")

	_set_player_skill(main, 0, 2, "商品做空1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	var supply_pressure_after_short := int(entry.get("temporary_supply_pressure", 0))
	_expect(supply_pressure_after_short > 0, "short-selling card creates temporary supply pressure instead of directly setting price")

	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	var volatility_before := int(entry.get("volatility", 4))
	var demand_pressure_before_stabilize := int(entry.get("temporary_demand_pressure", 0))
	var supply_pressure_before_stabilize := int(entry.get("temporary_supply_pressure", 0))
	_set_player_skill(main, 0, 2, "市场稳定1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	_expect(int(entry.get("temporary_demand_pressure", 0)) < demand_pressure_before_stabilize or int(entry.get("temporary_supply_pressure", 0)) < supply_pressure_before_stabilize, "market stabilization reduces temporary supply/demand pressure")
	_expect(int(entry.get("volatility", volatility_before)) < volatility_before, "market stabilization permanently reduces product volatility")
	_expect(_as_array(entry.get("price_history", [])).size() >= 4, "product market records a visible price path across economic card effects")

	var contract_card_income_before := int((_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "远期采购1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	_expect(int(entry.get("market_contract_demand", 0)) >= 3, "forward-purchase card adds sustained product demand pressure")
	_expect(float(entry.get("market_contract_seconds", 0.0)) >= 90.0, "forward-purchase card adds a visible real-time product contract duration")
	_expect(String(main.call("_product_market_boon_text", product_name)).contains("商品合约"), "product contract appears in product economy weather text")
	var players_after_forward := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	_expect(int((players_after_forward[0] as Dictionary).get("total_card_income", 0)) == contract_card_income_before + 120, "forward-purchase product contract records card-generated cash")

	_set_player_skill(main, 0, 2, "期货套保1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	_expect(int(entry.get("market_contract_supply", 0)) >= 3, "futures hedge card adds sustained product supply pressure")
	_expect(String(main.call("_product_market_boon_text", product_name)).contains("供+"), "futures hedge supply pressure appears in product economy weather text")

	_set_player_skill(main, 0, 2, "包销协议1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	var market_contract_seconds_before_age := float(entry.get("market_contract_seconds", 0.0))
	_expect(int(entry.get("market_contract_demand", 0)) >= 4, "distribution contract card strengthens sustained product demand pressure")
	_expect(float(entry.get("route_flow_multiplier", 1.0)) >= 1.2, "distribution contract card accelerates related product route flow")

	_set_player_skill(main, 0, 2, "商品催化1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	var growth_seconds_before_age := float(entry.get("growth_seconds", 0.0))
	_expect(float(entry.get("growth_multiplier", 1.0)) >= 2.0, "product catalyst card boosts the selected product's positive growth multiplier")
	_expect(growth_seconds_before_age >= 90.0, "product catalyst card adds a visible real-time duration")
	_expect(String(main.call("_product_market_boon_text", product_name)).contains("增速"), "product catalyst appears in product economy weather text")
	var product_status_tags := main.call("_product_public_status_tags", product_name) as Array
	var product_status_text := String(main.call("_public_status_tag_text", product_status_tags))
	_expect(product_status_text.contains("商品合约") and product_status_text.contains("增速") and product_status_text.contains("商路"), "product weather and contracts appear as unified public status tags")

	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var route_damage_before := int(city.get("trade_route_damage", 0))
	_set_player_skill(main, 0, 2, "商路黑客1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(int(city.get("trade_route_damage", 0)) == route_damage_before + 1, "route sabotage adds persistent trade-route damage")

	var insured_revenue_before := int(city.get("revenue_bonus", 0))
	_set_player_skill(main, 0, 2, "供应链保险1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(int(city.get("trade_route_damage", 0)) == route_damage_before, "supply-chain insurance repairs one route-damage pressure")
	_expect(int(city.get("revenue_bonus", 0)) == insured_revenue_before + 30, "supply-chain insurance adds permanent city income")

	_set_player_skill(main, 0, 2, "短期订单1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var contract_seconds_before_age := float(city.get("contract_seconds", 0.0))
	var contract_breakdown := main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary
	_expect(int(city.get("contract_income_bonus", 0)) >= 95, "short-term order card adds a temporary city contract income bonus")
	_expect(contract_seconds_before_age >= 90.0, "short-term order card adds a visible real-time contract duration")
	_expect(int(contract_breakdown.get("contract", 0)) >= 95, "temporary city contract appears in city income breakdown")
	_expect(String(main.call("_city_contract_status_text", city)).contains("+"), "temporary city contract appears in city contract status text")

	var route_flow_before := float(city.get("route_flow_multiplier", 1.0))
	_set_player_skill(main, 0, 2, "星港快线1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var route_flow_seconds_before_age := float(city.get("route_flow_seconds", 0.0))
	_expect(float(city.get("route_flow_multiplier", 1.0)) >= maxf(1.45, route_flow_before), "route-flow card accelerates the selected owned city's commercial flow")
	_expect(route_flow_seconds_before_age >= 90.0, "route-flow card adds a visible real-time duration")
	_expect(String(main.call("_city_route_flow_status_text", city)).contains("×"), "route-flow card appears in city flow status text")
	var city_status_tags := main.call("_city_public_status_tags", city) as Array
	var city_status_text := String(main.call("_public_status_tag_text", city_status_tags))
	_expect(city_status_text.contains("城市合约") and city_status_text.contains("流通") and city_status_text.contains("永久收入"), "city contracts, flow, and permanent income appear as unified public status tags")

	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var original_damage := int((districts[district_index] as Dictionary).get("damage", 0))
	var original_revenue_bonus := int(city.get("revenue_bonus", 0))
	(districts[district_index] as Dictionary)["damage"] = 0
	city["revenue_bonus"] = original_revenue_bonus + 260
	city["gdp_history"] = []
	city["last_gdp"] = 0
	city["last_gdp_delta"] = 0
	(districts[district_index] as Dictionary)["city"] = city
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var damage_penalty_before := int((main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary).get("damage_penalty", 0))
	var gdp_breakdown_before_damage := main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary
	main.call("_record_city_gdp_snapshot", district_index, int(gdp_breakdown_before_damage.get("net", 0)), gdp_breakdown_before_damage, "烟测受损前")
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	(districts[district_index] as Dictionary)["damage"] = original_damage + 6
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var gdp_breakdown_after_damage := main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary
	var damage_penalty_after := int(gdp_breakdown_after_damage.get("damage_penalty", 0))
	_expect(damage_penalty_after > damage_penalty_before, "district damage is reflected as a GDP penalty in city income breakdown")
	main.call("_record_city_gdp_snapshot", district_index, int(gdp_breakdown_after_damage.get("net", 0)), gdp_breakdown_after_damage, "烟测受损后")
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(_as_array(city.get("gdp_history", [])).size() >= 2, "city records a public GDP history across economy snapshots")
	_expect(int(city.get("last_gdp_delta", 0)) < 0, "city GDP history records the damage-driven GDP drop")
	_expect(String(main.call("_city_gdp_trend_text", city)).contains("GDP趋势"), "city GDP trend helper produces readable public trend text")
	_expect(String((main.call("_economy_dashboard_public_snapshot") as Dictionary).get("summary_text", "")).contains("GDP趋势"), "economy overview exposes city GDP trend text")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var region_codex_snapshot := coordinator.call("region_codex_public_snapshot", district_index) as Dictionary if coordinator != null else {}
	_expect(String(region_codex_snapshot.get("summary_text", "")).contains("区域可提供卡牌") and not str(region_codex_snapshot).contains("REGION_PRIVATE"), "region codex exposes only scene-owned public region facts")
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	(districts[district_index] as Dictionary)["damage"] = original_damage
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	city["revenue_bonus"] = original_revenue_bonus
	(districts[district_index] as Dictionary)["city"] = city
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts

	var gdp_baseline := int(main.call("_city_cycle_income", district_index, int(city.get("competition_matches", 0))))
	var derivative_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityGdpDerivativeRuntimeController") as CityGdpDerivativeRuntimeController
	_expect(derivative_controller != null, "city GDP derivative runtime controller is available to gameplay smoke tests")
	if derivative_controller == null:
		return
	derivative_controller.reset_state()
	var funded_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players).duplicate(true)
	funded_players[0]["cash"] = int((funded_players[0] as Dictionary).get("cash", 0)) + 1000
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = funded_players
	var gdp_card_income_before := int((_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[0] as Dictionary).get("total_card_income", 0))
	var long_skill := _runtime_card_definition(main, "城市买涨1")
	var long_open := derivative_controller.open_position(0, long_skill, district_index)
	var long_positions := derivative_controller.positions_for_district(district_index, true)
	_expect(bool(long_open.get("committed", false)) and long_positions.size() == 1, "city long-GDP card opens one Controller-owned anonymous position")
	var long_derivative := long_positions[0] as Dictionary
	_expect(float(long_derivative.get("duration_seconds", 0.0)) >= 60.0 and float(long_derivative.get("expires_at", 0.0)) > float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time), "city long-GDP derivative records a real-time holding window")
	derivative_controller.settle_district(district_index, gdp_baseline + 140, "烟测到期上涨", true)
	var players_after_long := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	_expect(int((players_after_long[0] as Dictionary).get("total_card_income", 0)) > gdp_card_income_before, "city long-GDP derivative pays out after a timed holding window when city GDP rises")

	var short_income_before := int((players_after_long[0] as Dictionary).get("total_card_income", 0))
	var short_skill := _runtime_card_definition(main, "城市做空1")
	var short_open := derivative_controller.open_position(0, short_skill, district_index)
	var short_positions := derivative_controller.positions_for_district(district_index, true)
	_expect(bool(short_open.get("committed", false)) and short_positions.size() == 1, "city short-GDP card opens through the same Controller")
	var short_derivative := short_positions[0] as Dictionary
	_expect(float(short_derivative.get("duration_seconds", 0.0)) >= 60.0 and float(short_derivative.get("expires_at", 0.0)) > float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time), "city short-GDP derivative records a real-time holding window")
	derivative_controller.settle_district(district_index, maxi(0, gdp_baseline - 120), "烟测到期下跌", true)
	var players_after_short := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	_expect(int((players_after_short[0] as Dictionary).get("total_card_income", 0)) > short_income_before, "city short-GDP derivative pays out after a timed holding window when city GDP falls")

	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var original_owner := int(city.get("owner", 0))
	city["owner"] = 1
	(districts[district_index] as Dictionary)["city"] = city
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var insurance_skill := _runtime_card_definition(main, "灾害保单1")
	var rejected_insurance := derivative_controller.open_position(0, insurance_skill, district_index)
	_expect(not bool(rejected_insurance.get("committed", true)) and derivative_controller.positions_for_district(district_index, true).is_empty(), "disaster-insurance GDP hedge can only be placed on the player's own city")
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	city["owner"] = original_owner
	(districts[district_index] as Dictionary)["city"] = city
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var insurance_income_before := int((_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[0] as Dictionary).get("total_card_income", 0))
	var insurance_open := derivative_controller.open_position(0, insurance_skill, district_index)
	var insurance_positions := derivative_controller.positions_for_district(district_index, true)
	_expect(bool(insurance_open.get("committed", false)) and insurance_positions.size() == 1, "disaster-insurance card opens one Controller-owned position")
	var insurance_derivative := insurance_positions[0] as Dictionary
	_expect(insurance_derivative.get("insurance", false) == true and String(insurance_derivative.get("direction", "")) == "down", "disaster-insurance card records a defensive GDP hedge")
	derivative_controller.settle_district(district_index, maxi(0, gdp_baseline - 150), "烟测保单赔付", true)
	var players_after_insurance := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	_expect(int((players_after_insurance[0] as Dictionary).get("total_card_income", 0)) > insurance_income_before, "disaster-insurance card pays when the insured city GDP falls")
	derivative_controller.reset_state()

	main.call("_age_economic_boons", 30.0)
	product_market = _product_market_for_test(main)
	entry = product_market.get(product_name, {}) as Dictionary
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(is_equal_approx(float(entry.get("growth_seconds", 0.0)), maxf(0.0, growth_seconds_before_age - 30.0)), "temporary product-growth boon counts down by elapsed seconds")
	_expect(is_equal_approx(float(entry.get("market_contract_seconds", 0.0)), maxf(0.0, market_contract_seconds_before_age - 30.0)), "temporary product contract counts down by elapsed seconds")
	_expect(is_equal_approx(float(city.get("route_flow_seconds", 0.0)), maxf(0.0, route_flow_seconds_before_age - 30.0)), "temporary route-flow boon counts down by elapsed seconds")
	_expect(is_equal_approx(float(city.get("contract_seconds", 0.0)), maxf(0.0, contract_seconds_before_age - 30.0)), "temporary city contract counts down by elapsed seconds")
	var player_after_economy := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)[0] as Dictionary
	_expect(String(main.call("_player_cash_path_text", player_after_economy)).contains("→"), "economy helpers keep a multi-step recent cash path for overview menus")
	_clear_player_cooldown(main, 0)


func _verify_monster_resource_and_collision_system(main: Node, district_index: int) -> void:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var auto_monsters := _as_array(main.get("auto_monsters"))
	if district_index < 0 or district_index >= districts.size() or auto_monsters.size() < 2:
		_expect(false, "monster resource/collision test has a district and at least two monsters")
		return
	var district := districts[district_index] as Dictionary
	var products := _as_array(district.get("products", []))
	_expect(not products.is_empty(), "resource/collision test district has local products")
	if products.is_empty():
		return
	var focus_product := String(products[0])
	var center := main.call("_district_center", district_index) as Vector2
	for i in range(2):
		var actor := auto_monsters[i] as Dictionary
		actor["position"] = district_index
		actor["world_position"] = center
		actor["down"] = false
		auto_monsters[i] = actor
	var resource_actor := auto_monsters[0] as Dictionary
	resource_actor["resource_focus"] = [focus_product]
	resource_actor["resource_drain"] = 2
	auto_monsters[0] = resource_actor
	main.set("auto_monsters", auto_monsters)
	var matches := _as_array(_monster_controller(main).call("_monster_resource_matches", resource_actor, district_index))
	_expect(matches.has(focus_product), "monster resource matching detects district goods")
	var damage_before := int(((((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array)[district_index] as Dictionary).get("damage", 0))
	var drained := int(_monster_controller(main).call("_auto_monster_resource_drain", resource_actor, district_index, "烟测资源"))
	var districts_after_drain := ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array
	var district_after_drain := districts_after_drain[district_index] as Dictionary
	_expect(drained == 2, "resource drain applies the monster's resource-damage value")
	_expect(int(district_after_drain.get("damage", 0)) == damage_before + 2, "resource drain damages the district/city HP track")
	_expect(String(district_after_drain.get("last_damage_source", "")).contains("资源吸取"), "district records the latest monster resource damage source")
	_expect(_map_effects_contain(main, "stomp"), "monster resource damage emits a temporary stomp map animation")

	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var neighbor_index := -1
	for neighbor_variant in _as_array((districts[district_index] as Dictionary).get("neighbors", [])):
		var candidate := int(neighbor_variant)
		if candidate >= 0 and candidate < districts.size() and not bool((districts[candidate] as Dictionary).get("destroyed", false)):
			neighbor_index = candidate
			break
	if neighbor_index >= 0:
		var from_position := main.call("_district_center", district_index) as Vector2
		var to_position := main.call("_district_center", neighbor_index) as Vector2
		var walking_actor := (auto_monsters[0] as Dictionary).duplicate(true)
		walking_actor["position"] = neighbor_index
		walking_actor["movement_traits"] = []
		walking_actor["move_damage"] = 1
		var path_damage_before := 0
		for district_variant in _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts):
			path_damage_before += int((district_variant as Dictionary).get("damage", 0))
		var walking_damage := int(_monster_controller(main).call("_apply_auto_monster_path_effects", walking_actor, from_position, to_position, "烟测步行", "walk"))
		var path_damage_after_walk := 0
		for district_variant in _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts):
			path_damage_after_walk += int((district_variant as Dictionary).get("damage", 0))
		var flying_actor := walking_actor.duplicate(true)
		flying_actor["movement_traits"] = ["flying"]
		var flying_damage := int(_monster_controller(main).call("_apply_auto_monster_path_effects", flying_actor, from_position, to_position, "烟测飞行", "fly"))
		var path_damage_after_fly := 0
		for district_variant in _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts):
			path_damage_after_fly += int((district_variant as Dictionary).get("damage", 0))
		_expect(walking_damage > 0 and path_damage_after_walk > path_damage_before, "walking monster path movement crushes regions")
		_expect(flying_damage == 0 and path_damage_after_fly == path_damage_after_walk, "flying monster path movement does not crush regions")

	var ocean_index := -1
	var land_index := -1
	districts = _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	for i in range(districts.size()):
		var terrain := String((districts[i] as Dictionary).get("terrain", "land"))
		if terrain == "ocean" and ocean_index < 0:
			ocean_index = i
		if terrain == "land" and land_index < 0:
			land_index = i
	if ocean_index >= 0 and land_index >= 0:
		var aquatic_actor := {
			"movement_traits": ["aquatic"],
			"terrain_move_multiplier": {"ocean": 1.35, "land": 0.72},
		}
		_expect(float(_monster_controller(main).call("_monster_terrain_move_multiplier", aquatic_actor, ocean_index)) > float(_monster_controller(main).call("_monster_terrain_move_multiplier", aquatic_actor, land_index)), "aquatic monster movement is faster in ocean than on land")

	auto_monsters = _as_array(main.get("auto_monsters"))
	var target_before := auto_monsters[1] as Dictionary
	var target_durability_before := int(target_before.get("hp", 0)) + int(target_before.get("armor", 0))
	var hit := bool(_monster_controller(main).call("_auto_monster_use_action_on_other", 0, 1, {
		"name": "烟测撞击",
		"range": 110.0,
		"damage": 2,
		"knockback": 120.0,
		"text": "烟测用的近距离撞击。",
	}, "烟测遭遇"))
	var active_wagers := _as_array(main.get("active_monster_wagers"))
	if not active_wagers.is_empty():
		var wager_id := int((active_wagers[0] as Dictionary).get("wager_id", -1))
		_monster_controller(main).call("_force_monster_wager_missing_bets", wager_id, "烟测自动结束")
		_monster_controller(main).call("_settle_monster_wager", wager_id, "烟测自动结束")
	auto_monsters = _as_array(main.get("auto_monsters"))
	var target_after := auto_monsters[1] as Dictionary
	var target_durability_after := int(target_after.get("hp", 0)) + int(target_after.get("armor", 0))
	_expect(hit, "monster encounter action resolves against another monster")
	_expect(target_durability_after < target_durability_before, "monster encounter action reduces target durability through HP or armor")
	_expect(_map_effects_contain(main, "melee"), "monster encounter action emits a temporary melee attack animation")
	var districts_after_hit := ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array
	var total_damage_after_hit := 0
	for district_variant in districts_after_hit:
		var damage_district := district_variant as Dictionary
		total_damage_after_hit += int(damage_district.get("damage", 0))
	_expect(total_damage_after_hit > damage_before + 2, "monster knockback collision damages at least one region")


func _settle_all_active_monster_wagers(main: Node, reason: String) -> void:
	for _attempt in range(8):
		var active_wagers := _as_array(main.get("active_monster_wagers"))
		if active_wagers.is_empty():
			return
		for wager_variant in active_wagers:
			var wager := wager_variant as Dictionary
			var wager_id := int(wager.get("wager_id", -1))
			if wager_id < 0:
				continue
			_monster_controller(main).call("_force_monster_wager_missing_bets", wager_id, reason)
			_monster_controller(main).call("_settle_monster_wager", wager_id, reason)
		_monster_controller(main).call("_update_monster_wagers", 999.0)
	if not _as_array(main.get("active_monster_wagers")).is_empty():
		main.set("active_monster_wagers", [])


func _verify_special_monster_passives(main: Node) -> void:
	var saved_auto_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var saved_special_monster_timer := float(main.get("special_monster_timer"))
	var saved_log_lines := _public_log_messages(main).duplicate(true)
	var saved_action_callouts := _visual_cue_array(main, "action_callouts").duplicate(true)
	var start_district := maxi(0, int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district))

	var ember_ring_index := int(main.call("_monster_catalog_index_by_name", "焰环幼星"))
	_expect(ember_ring_index >= 0, "monster catalog contains 焰环幼星")
	if ember_ring_index >= 0:
		var ember_ring := _monster_controller(main).call("_make_auto_monster", 0, ember_ring_index, start_district) as Dictionary
		ember_ring["hp"] = 18
		main.set("auto_monsters", [ember_ring])
		_monster_controller(main).call("_auto_monster_take_damage", 0, 3, "烟测星焰炸弹", -1)
		var ember_ring_after := (_as_array(main.get("auto_monsters"))[0]) as Dictionary
		_expect(int(ember_ring_after.get("hp", 0)) == 15, "星焰炸弹 self-damage reduces 焰环幼星 HP by 3")
		_expect(bool(_monster_controller(main).call("_is_auto_ember_ring_energy_active", 0)), "星焰能量 activates at 15 HP")
		_expect(bool(ember_ring_after.get("ember_ring_energy_announced", false)), "星焰能量 activation is announced once")

	var blue_lancer_index := int(main.call("_monster_catalog_index_by_name", "蓝锋骑士"))
	_expect(blue_lancer_index >= 0, "monster catalog contains 蓝锋骑士")
	if blue_lancer_index >= 0:
		var blue_lancer := _monster_controller(main).call("_make_auto_monster", 0, blue_lancer_index, start_district) as Dictionary
		blue_lancer["hp"] = 20
		main.set("auto_monsters", [blue_lancer])
		_monster_controller(main).call("_maybe_announce_auto_blue_lancer_reactive_armor", 0)
		var blue_lancer_active := (_as_array(main.get("auto_monsters"))[0]) as Dictionary
		_expect(bool(blue_lancer_active.get("blue_lancer_reactive_armor_active", false)), "蓝锋反应甲 activates at 20 HP")
		_expect(int(_monster_controller(main).call("_auto_monster_damage_bonus_from_passives", 0)) == 1, "蓝锋反应甲 grants +1 outgoing damage")
		var blue_lancer_hp_before := int(blue_lancer_active.get("hp", 0))
		_monster_controller(main).call("_auto_monster_take_damage", 0, 3, "烟测近战", -1)
		var blue_lancer_after := (_as_array(main.get("auto_monsters"))[0]) as Dictionary
		_expect(blue_lancer_hp_before - int(blue_lancer_after.get("hp", 0)) == 2, "蓝锋反应甲 reduces incoming damage by 1")

	main.set("auto_monsters", saved_auto_monsters)
	main.set("special_monster_timer", saved_special_monster_timer)
	_replace_public_log_messages(main, saved_log_lines)
	_set_visual_cue_array(main, "action_callouts", saved_action_callouts)


func _verify_card_art_script() -> void:
	var script := load(CARD_ART_SCRIPT_PATH)
	_expect(script != null, "card art script loads")
	if script == null:
		return
	var card_view := script.new() as Control
	_expect(card_view != null, "card art script instantiates a Control")
	if card_view != null:
		get_root().add_child(card_view)
		card_view.call("set_card", "怪兽·孢雾海皇1", "monster_card", "怪兽卡 / 召唤", Color("#fb7185"), 1, false, "HP50｜95s｜移190m｜怪区邻接")
		_expect(String(card_view.get("card_stats")).contains("HP50"), "card art accepts an on-face monster attribute line")
		card_view.call("set_card", "环港走私议会", "player_role", "角色卡 / 蜂冠商族", Color("#38bdf8"), 1, false, "公开身份｜购牌:环晶电池+1")
		_expect(String(card_view.get("card_kind")) == "player_role" and String(card_view.get("card_stats")).contains("公开身份"), "card art accepts public player-role card faces without starter fingerprints")
		card_view.queue_free()


func _verify_monster_art_script() -> void:
	var script := load(MONSTER_ART_SCRIPT_PATH)
	_expect(script != null, "monster art script loads")
	if script == null:
		return
	var monster_view := script.new() as Control
	_expect(monster_view != null, "monster art script instantiates a Control")
	if monster_view != null:
		get_root().add_child(monster_view)
		monster_view.call(
			"set_monster",
			"孢雾海皇",
			"自动怪兽",
			40,
			0,
			"190m",
			{
				"accent": Color("#94a3b8"),
				"secondary": Color("#e2e8f0"),
				"glyph": "瘴",
				"motif": "miasma",
				"subtitle": "星兽档案",
			},
			false
		)
		monster_view.queue_free()


func _count_terrain(districts: Array) -> Dictionary:
	var counts := {"land": 0, "ocean": 0}
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var terrain := String(district.get("terrain", ""))
		if counts.has(terrain):
			counts[terrain] = int(counts[terrain]) + 1
	return counts


func _first_terrain_district(districts: Array, terrain_name: String) -> int:
	for i in range(districts.size()):
		var district_variant: Variant = districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		if String(district.get("terrain", "")) == terrain_name:
			return i
	return -1


func _first_buildable_land_district(districts: Array) -> int:
	for i in range(districts.size()):
		var district_variant: Variant = districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		if String(district.get("terrain", "")) == "land" and city.is_empty() and not bool(district.get("destroyed", false)):
			return i
	return -1


func _verify_v06_market_rule_contract() -> bool:
	var snapshot := JSON.stringify(V06_RULES_SNAPSHOT.compose(1120.0))
	var rulebook := FileAccess.get_file_as_string("res://docs/tabletop_rulebook_v06.md")
	return snapshot.contains("召唤时点完全自愿") \
		and snapshot.contains("未召唤不阻断经济、设施或购牌") \
		and snapshot.contains("全局可查看；来源区域中心受光时才可购买") \
		and snapshot.contains("同区每只 +1") \
		and snapshot.contains("相邻每只 +0.5") \
		and snapshot.contains("最高 5x") \
		and snapshot.contains("向上取整") \
		and snapshot.contains("所有玩家同价") \
		and snapshot.contains("倒地或过期怪兽不计") \
		and rulebook.contains("每 120 秒完成一周权威自转") \
		and rulebook.contains("有效 5 秒 `world_effective` 时间") \
		and rulebook.contains("观察镜头不属于")


func _ai_controller(main: Node) -> Node:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	if controller == null:
		push_error("Smoke test requires scene-owned AiRuntimeController.")
	return controller


func _runtime_coordinator(main: Node) -> Node:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if coordinator == null:
		push_error("Smoke test requires scene-owned GameRuntimeCoordinator.")
	return coordinator


func _visual_cue_array(main: Node, key: String) -> Array:
	var coordinator := _runtime_coordinator(main)
	var snapshot_variant: Variant = coordinator.call("visual_cue_public_snapshot") if coordinator != null else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return _as_array(snapshot.get(key, [])).duplicate(true)


func _set_visual_cue_array(main: Node, key: String, value: Array) -> void:
	var coordinator := _runtime_coordinator(main)
	if coordinator == null:
		return
	var snapshot_variant: Variant = coordinator.call("visual_cue_public_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	snapshot[key] = value.duplicate(true)
	coordinator.call("import_legacy_visual_cues", snapshot)


func _advance_card_resolution_frame_for_test(main: Node, delta_seconds: float) -> void:
	var coordinator := _runtime_coordinator(main)
	if coordinator == null:
		return
	var commands_variant: Variant = coordinator.call("advance_card_resolution_frame", delta_seconds)
	var commands: Array = commands_variant if commands_variant is Array else []
	for command_variant in commands:
		if command_variant is Dictionary and main.has_method("_apply_card_resolution_controller_transition"):
			main.call("_apply_card_resolution_controller_transition", command_variant as Dictionary)


func _victory_controller(main: Node) -> Node:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/VictoryControlRuntimeController")
	if controller == null:
		push_error("Smoke test requires scene-owned VictoryControlRuntimeController.")
	return controller


func _victory_test_world(player_zero_regions: Array, player_one_regions: Array, player_zero_cash_cents: int, player_one_cash_cents: int) -> Dictionary:
	return _victory_world_for_players([player_zero_regions, player_one_regions], [player_zero_cash_cents, player_one_cash_cents])


func _victory_three_player_world(player_zero_regions: Array, player_one_regions: Array, player_two_regions: Array, cash_values: Array) -> Dictionary:
	return _victory_world_for_players([player_zero_regions, player_one_regions, player_two_regions], cash_values)


func _victory_world_for_players(region_sets: Array, cash_values: Array) -> Dictionary:
	var players: Array = []
	var regions: Array = []
	for player_index in range(region_sets.size()):
		players.append({
			"player_index": player_index,
			"eliminated": false,
			"cash_ledger_cents": int(cash_values[player_index]) if player_index < cash_values.size() else 0,
			"audit_assets": {
				"project_slot_count": 0,
				"ordinary_hand_count": 0,
				"military_unit_count": 0,
			},
		})
	var district_index := 0
	for owner_index in range(region_sets.size()):
		var amounts: Array = region_sets[owner_index] if region_sets[owner_index] is Array else []
		for amount_variant in amounts:
			var amount := maxi(0, int(amount_variant))
			var player_gdp_by_index := {}
			for player_index in range(region_sets.size()):
				player_gdp_by_index[str(player_index)] = amount if player_index == owner_index else 0
			regions.append({
				"region_id": "smoke_region_%d" % district_index,
				"district_index": district_index,
				"destroyed": false,
				"region_gdp_per_minute": amount * 2,
				"player_gdp_by_index": player_gdp_by_index,
			})
			district_index += 1
	return {
		"schema_version": "v0.5.victory-world.1",
		"depth_tier": "I",
		"players": players,
		"regions": regions,
		"clock_pause": {},
	}


func _diagnostics(main: Node) -> GameplayBalanceDiagnosticsRuntimeService:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if not (coordinator is GameRuntimeCoordinator):
		push_error("Smoke test requires scene-owned GameplayBalanceDiagnosticsRuntimeService.")
		return null
	return coordinator.gameplay_balance_diagnostics_service()


func _monster_controller(main: Node) -> Node:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController")
	if controller == null:
		push_error("Smoke test requires scene-owned MonsterRuntimeController.")
	return controller


func _military_controller(main: Node) -> Node:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeController")
	if controller == null:
		push_error("Smoke test requires scene-owned MilitaryRuntimeController.")
	return controller


func _weather_controller(main: Node) -> Node:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/WeatherRuntimeController")
	if controller == null:
		push_error("Smoke test requires scene-owned WeatherRuntimeController.")
	return controller


func _contract_controller(main: Node) -> Node:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController")
	if controller == null:
		push_error("Smoke test requires scene-owned ContractRuntimeController.")
	return controller


func _contract_pending_offers(main: Node) -> Array:
	var controller := _contract_controller(main)
	var value: Variant = controller.call("pending_offers_snapshot", true) if controller != null else []
	return (value as Array).duplicate(true) if value is Array else []


func _reset_contract_runtime(main: Node) -> void:
	var controller := _contract_controller(main)
	if controller != null:
		controller.call("reset_state")


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _public_log_messages(main: Node) -> Array:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	return coordinator.presentation_recent_public_log_messages(90) if coordinator != null else []


func _replace_public_log_messages(main: Node, messages: Array) -> void:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	if coordinator != null:
		coordinator.import_legacy_viewer_feedback(messages)


func _map_effects_contain(main: Node, kind: String) -> bool:
	for effect_variant in _visual_cue_array(main, "map_event_effects"):
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		if String(effect.get("kind", "")) == kind:
			return true
	return false


func _map_effects_contain_style(main: Node, kind: String, style: String) -> bool:
	for effect_variant in _visual_cue_array(main, "map_event_effects"):
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		if String(effect.get("kind", "")) == kind and String(effect.get("card_style", "")) == style:
			return true
	return false


func _map_effects_contain_min_duration(main: Node, kind: String, min_duration: float) -> bool:
	for effect_variant in _visual_cue_array(main, "map_event_effects"):
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		if String(effect.get("kind", "")) == kind and float(effect.get("duration", 0.0)) >= min_duration:
			return true
	return false


func _regions_start_with_terrain_goods(main: Node) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var ocean_products := _as_array(main.call("_product_pool_for_terrain", "ocean"))
	var land_products := _as_array(main.call("_product_pool_for_terrain", "land"))
	var saw_land := false
	var saw_ocean := false
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var terrain := String(district.get("terrain", "land"))
		var products := _as_array(district.get("products", []))
		var demands := _as_array(district.get("demands", []))
		if products.size() != 1:
			return false
		if demands.size() != 1:
			return false
		var product_name := String(products[0])
		if terrain == "ocean":
			saw_ocean = true
			if not ocean_products.has(product_name):
				return false
		else:
			saw_land = true
			if not land_products.has(product_name):
				return false
	return saw_land and saw_ocean


func _city_has_single_goods(main: Node, district_index: int) -> bool:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	if district_index < 0 or district_index >= districts.size():
		return false
	var district := districts[district_index] as Dictionary
	var city := district.get("city", {}) as Dictionary
	if city.is_empty() or not bool(city.get("active", true)):
		return false
	return (city.get("products", []) as Array).size() == 1 and (city.get("demands", []) as Array).size() == 1


func _verify_card_codex_uses_unified_categories(main: Node) -> bool:
	var monster_card := String(main.call("_monster_card_name", 0, 1))
	var monster_names := _as_array(main.call("_card_codex_names", "monster"))
	var monster_skill_names := _as_array(main.call("_card_codex_names", "monster_skill"))
	var military_names := _as_array(main.call("_card_codex_names", "military"))
	var interaction_names := _as_array(main.call("_card_codex_names", "interaction"))
	var city_names := _as_array(main.call("_card_codex_names", "city"))
	var commodity_names := _as_array(main.call("_card_codex_names", "commodity"))
	var futures_names := _as_array(main.call("_card_codex_names", "futures"))
	var finance_names := _as_array(main.call("_card_codex_names", "finance"))
	var contract_names := _as_array(main.call("_card_codex_names", "contract"))
	var business_alias_names := _as_array(main.call("_card_codex_names", "business"))
	var economy_alias_names := _as_array(main.call("_card_codex_names", "economy"))
	var all_names := _as_array(main.call("_card_codex_names", "all"))
	var coordinator := _runtime_coordinator(main)
	var monster_text := String((coordinator.call("card_codex_public_detail_snapshot", monster_card, 0, maxi(1, monster_names.size())) as Dictionary).get("summary_text", ""))
	var contract_text := String((coordinator.call("card_codex_public_detail_snapshot", "区域供需合约1", 0, maxi(1, contract_names.size())) as Dictionary).get("summary_text", ""))
	var district_supply_card := ""
	var district_supply_index := -1
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	for district_index in range(districts.size()):
		var district := districts[district_index] as Dictionary
		var choices := _as_array(district.get("card_choices", []))
		if not choices.is_empty():
			district_supply_card = String(choices[0])
			district_supply_index = district_index
			break
	var ok := true
	var failures := []
	if not monster_names.has(monster_card):
		failures.append("monster")
	if not monster_skill_names.has("移动1"):
		failures.append("monster_skill")
	if not military_names.has("制空战斗机1"):
		failures.append("military")
	if not interaction_names.has("相位否决1") or not interaction_names.has("星链拆解1"):
		failures.append("interaction")
	if not city_names.has("应急修复1"):
		failures.append("city")
	if not commodity_names.has("远期采购1"):
		failures.append("commodity")
	if not futures_names.has("商品看涨1") or not futures_names.has("港仓囤货1"):
		failures.append("futures")
	if not finance_names.has("城市买涨1") or not finance_names.has("城市做空1"):
		failures.append("finance")
	if not contract_names.has("区域供需合约1"):
		failures.append("contract")
	if not business_alias_names.has("区域供需合约1"):
		failures.append("business_alias")
	if not economy_alias_names.has("远期采购1") or not economy_alias_names.has("城市买涨1"):
		failures.append("economy_alias")
	if not all_names.has(monster_card) or not all_names.has("区域供需合约1"):
		failures.append("all")
	if String(main.call("_card_codex_filter_label", "monster")) != "怪兽牌":
		failures.append("monster_label")
	if String(main.call("_card_codex_filter_label", "monster_skill")) != "怪兽技能":
		failures.append("monster_skill_label")
	if String(main.call("_card_codex_filter_label", "military")) != "军队/军令":
		failures.append("military_label")
	if String(main.call("_card_codex_filter_label", "interaction")) != "玩家互动":
		failures.append("interaction_label")
	if String(main.call("_card_codex_filter_label", "futures")) != "商品期货":
		failures.append("futures_label")
	if String(main.call("_card_codex_filter_label", "finance")) != "金融/GDP":
		failures.append("finance_label")
	if String(main.call("_card_codex_filter_label", "business")) != "经营/合约":
		failures.append("business_alias_label")
	if not monster_text.contains("怪兽牌"):
		failures.append("monster_text")
	if not contract_text.contains("合约"):
		failures.append("contract_text")
	if district_supply_card == "" or String(main.call("_card_supply_layer_for_card", district_supply_card)) != "区域补给":
		failures.append("district_supply_layer")
	if district_supply_card != "":
		var public_source := _card_codex_public_source_service(main)
		var district_card_facts: Dictionary = public_source.call("compose_card_facts", district_supply_card, district_supply_index) if public_source != null else {}
		var district_card_visible_name := String(district_card_facts.get("display_name", ""))
		if district_card_visible_name == "" or not String(district_card_facts.get("detail_tooltip", "")).contains(district_card_visible_name):
			failures.append("district_tooltip_preview")
	if _card_presentation_category_id(main, _runtime_card_definition(main, "相位否决1")) != "interaction":
		failures.append("phase_cancel_interaction_category")
	if _card_presentation_category_id(main, _runtime_card_definition(main, "商品看涨1")) != "futures":
		failures.append("futures_category")
	if _card_presentation_category_id(main, _runtime_card_definition(main, "城市买涨1")) != "finance":
		failures.append("finance_category")
	ok = failures.is_empty()
	if not failures.is_empty():
		print("Card codex category failures: %s" % " / ".join(failures))
	return ok


func _first_empty_land_district_for_contract(main: Node, excluded: Array = []) -> int:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	for i in range(districts.size()):
		if excluded.has(i):
			continue
		var district_variant: Variant = districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		if String(district.get("terrain", "")) != "land" or bool(district.get("destroyed", false)):
			continue
		var city := district.get("city", {}) as Dictionary
		if city.is_empty():
			return i
	return -1


func _prepare_land_pair_for_contract_test(main: Node) -> Dictionary:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
	var chosen := []
	for i in range(districts.size()):
		var district_variant: Variant = districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		if String(district.get("terrain", "")) != "land" or bool(district.get("destroyed", false)):
			continue
		var city := district.get("city", {}) as Dictionary
		if city.is_empty():
			chosen.append(i)
			if chosen.size() >= 2:
				break
	for i in range(districts.size()):
		if chosen.size() >= 2:
			break
		if chosen.has(i):
			continue
		var district_variant: Variant = districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		if String(district.get("terrain", "")) != "land" or bool(district.get("destroyed", false)):
			continue
		chosen.append(i)
	if chosen.size() < 2:
		return {}
	for index_variant in chosen:
		var index := int(index_variant)
		var district := districts[index] as Dictionary
		district["city"] = {}
		districts[index] = district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	return {"source": int(chosen[0]), "target": int(chosen[1])}


func _test_city_product_names(city: Dictionary) -> Array:
	var result := []
	for product_variant in city.get("products", []):
		var product := product_variant as Dictionary
		result.append(String(product.get("name", "")))
	return result


func _test_city_demand_names(city: Dictionary) -> Array:
	var result := []
	for demand_variant in city.get("demands", []):
		result.append(String(demand_variant))
	return result


func _test_contract_product(main: Node, source_index: int, target_index: int) -> String:
	var districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
	var source_city := (districts[source_index] as Dictionary).get("city", {}) as Dictionary
	var target_city := (districts[target_index] as Dictionary).get("city", {}) as Dictionary
	var source_products := _test_city_product_names(source_city)
	var target_demands := _test_city_demand_names(target_city)
	var market := _product_market_for_test(main)
	for product_variant in market.keys():
		var product_name := String(product_variant)
		if product_name != "" and not source_products.has(product_name) and not target_demands.has(product_name):
			return product_name
	for product_variant in market.keys():
		var product_name := String(product_variant)
		if product_name != "":
			return product_name
	return "环晶电池"


func _verify_area_trade_contract_accept_and_decline(_main: Node) -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var main := packed.instantiate()
	var fixture_save_path := "user://test_runs/smoke_area_trade_contract_fixture.save"
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH) as Node
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", fixture_save_path))
	if not save_override_ready:
		main.free()
		return false
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	get_root().add_child(main)
	main.call("_new_game")
	main.set_process(false)
	var saved_force_duration: float = float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous: float = float(main.get("card_resolution_force_simultaneous_window"))
	var ok := true
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	_reset_contract_runtime(main)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_force_duration", 5.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	var land_pair := _prepare_land_pair_for_contract_test(main)
	var source_index := int(land_pair.get("source", -1))
	var target_index := int(land_pair.get("target", -1))
	if source_index < 0 or target_index < 0:
		ok = false
	else:
		var players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		for i in range(players.size()):
			var player := players[i] as Dictionary
			player["cash"] = 5000
			players[i] = player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		ok = ok and CITY_FIXTURES.create_city_bool(main, 0, source_index, "合约测试供给")
		ok = ok and CITY_FIXTURES.create_city_bool(main, 1, target_index, "合约测试需求")
		var product_name := _test_contract_product(main, source_index, target_index)
		var flow_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var flow_source_district := flow_districts[source_index] as Dictionary
		var flow_source_city := flow_source_district.get("city", {}) as Dictionary
		var flow_demands := _as_array(flow_source_city.get("demands", [])).duplicate(true)
		if not flow_demands.has(product_name):
			flow_demands.append(product_name)
		flow_source_city["demands"] = flow_demands
		flow_source_district["city"] = flow_source_city
		flow_districts[source_index] = flow_source_district
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = flow_districts
		var skill := main.call("_make_skill", "区域供需合约1") as Dictionary
		skill["play_product"] = product_name
		skill["play_flow_required"] = 1
		var contract_controller := _contract_controller(main)
		var project_districts := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts).duplicate(true)
		var project_target := project_districts[target_index] as Dictionary
		var project_city := (project_target.get("city", {}) as Dictionary).duplicate(true)
		project_city["projects"] = [{"project_id": "smoke-contract-target", "product_id": product_name, "direction": "demand", "active": true, "controller_player_index": 1}]
		project_target["city"] = project_city
		project_districts[target_index] = project_target
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = project_districts
		var missing_pair_context := contract_controller.call("offer_context", skill, 0, -1, -1, product_name) as Dictionary
		ok = ok and String(missing_pair_context.get("error", "")) != ""
		var queue_players := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var queue_player := queue_players[0] as Dictionary
		var queue_slots := _as_array(queue_player.get("slots", []))
		if queue_slots.is_empty():
			queue_slots.append(null)
		queue_slots[0] = skill.duplicate(true)
		queue_player["slots"] = queue_slots
		queue_players[0] = queue_player
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = queue_players
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = product_name
		contract_controller.call("set_selection_state", -1, -1)
		ok = ok and not bool(main.call("_queue_skill_resolution", 0, 0, -1))
		ok = ok and _as_array(main.get("card_resolution_queue")).is_empty() and _contract_pending_offers(main).is_empty()
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = source_index
		contract_controller.call("select_source_district", source_index, product_name)
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = target_index
		contract_controller.call("select_target_district", target_index, product_name)
		var selection := contract_controller.call("selection_snapshot") as Dictionary
		ok = ok and int(selection.get("source_district", -1)) == source_index
		ok = ok and int(selection.get("target_district", -1)) == target_index
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = product_name
		var context := contract_controller.call("offer_context", skill, 0, source_index, target_index, product_name) as Dictionary
		ok = ok and String(context.get("error", "")) == ""
		var target_owner := int(context.get("target_owner", -1))
		var products := context.get("products", []) as Array
		ok = ok and target_owner == 1 and products.has(product_name)
		var entry := {
			"resolution_id": 90001,
			"player_index": 0,
			"selected_district": source_index,
			"selected_trade_product": product_name,
			"contract_source_district": source_index,
			"contract_target_district": target_index,
			"contract_target_owner": target_owner,
			"contract_products": products.duplicate(true),
			"contract_response": "pending",
			"skill": skill.duplicate(true),
		}
		# The public reveal itself must not expose signing controls.
		main.set("active_card_resolution", entry.duplicate(true))
		main.set("card_resolution_timer", 5.0)
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = target_owner
		main.call("_refresh_ui")
		var player_box := main.get("player_box") as VBoxContainer
		ok = ok and player_box != null and not _container_label_text_contains(player_box, "匿名合约签署窗口")
		main.set("active_card_resolution", {})
		main.set("card_resolution_timer", 0.0)

		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
		ok = ok and bool(main.call("_queue_skill_resolution", 0, 0, -1))
		ok = ok and _contract_pending_offers(main).is_empty()
		ok = ok and (main.get("active_card_resolution") as Dictionary).is_empty()
		_advance_card_resolution_frame_for_test(main, 0.49)
		ok = ok and _contract_pending_offers(main).is_empty()
		_advance_card_resolution_frame_for_test(main, 0.02)
		var active_contract_reveal := main.get("active_card_resolution") as Dictionary
		ok = ok and not active_contract_reveal.is_empty()
		ok = ok and int(active_contract_reveal.get("contract_source_district", -1)) == source_index
		ok = ok and int(active_contract_reveal.get("contract_target_district", -1)) == target_index
		ok = ok and _contract_pending_offers(main).is_empty()
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = target_owner
		main.call("_refresh_ui")
		player_box = main.get("player_box") as VBoxContainer
		ok = ok and player_box != null and not _container_label_text_contains(player_box, "匿名合约签署窗口")
		_advance_card_resolution_frame_for_test(main, 4.90)
		ok = ok and _contract_pending_offers(main).is_empty()
		ok = ok and not (main.get("active_card_resolution") as Dictionary).is_empty()
		_advance_card_resolution_frame_for_test(main, 0.20)
		var pending_offers := _contract_pending_offers(main)
		ok = ok and pending_offers.size() == 1
		ok = ok and not bool(main.call("_is_card_resolution_busy"))
		var queued_contract_id := -1
		if not pending_offers.is_empty():
			var queued_offer := pending_offers[0] as Dictionary
			queued_contract_id = int(queued_offer.get("resolution_id", queued_offer.get("contract_offer_id", -1)))
			ok = ok and is_equal_approx(float(queued_offer.get("contract_decision_timer", 0.0)), 5.0)
		_set_player_skill(main, 2, 40, "舆论操控1")
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 2
		ok = ok and bool(main.call("_queue_skill_resolution", 2, 40, -1))
		ok = ok and _contract_pending_offers(main).size() == 1
		main.set("card_resolution_queue", [])
		main.set("next_card_resolution_queue", [])
		main.set("active_card_resolution", {})
		main.set("card_resolution_timer", 0.0)
		main.set("card_resolution_simultaneous_timer", 0.0)
		main.set("card_resolution_auction_timer", 0.0)
		main.set("card_resolution_auction_open", false)
		main.set("card_resolution_batch_locked", false)
		main.set("card_resolution_batch_reference_player", -1)
		main.set("last_card_resolution_player_index", -1)
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = target_owner
		var history := _as_array(main.get("resolved_card_history")).duplicate(true)
		for i in range(history.size()):
			var history_entry := history[i] as Dictionary
			if int(history_entry.get("resolution_id", -1)) != queued_contract_id:
				continue
			history_entry["public_owner_revealed"] = true
			history_entry["public_owner_label"] = "归属：玩家1"
			history_entry["guessers"] = [2]
			history[i] = history_entry
			break
		main.set("resolved_card_history", history)
		main.call("_refresh_ui")
		player_box = main.get("player_box") as VBoxContainer
		ok = ok and player_box != null and _container_label_text_contains(player_box, "匿名合约签署窗口")
		ok = ok and player_box != null and _container_label_text_contains(player_box, "不会阻塞其他玩家继续出牌")
		ok = ok and player_box != null and _container_button_text_contains(player_box, "签约") and _container_button_text_contains(player_box, "拒绝")
		var players_before_accept := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var target_cash_before := int((players_before_accept[target_owner] as Dictionary).get("cash", 0))
		ok = ok and bool((contract_controller.call("respond_to_offer", target_owner, queued_contract_id, true, false) as Dictionary).get("committed", false))
		ok = ok and _contract_pending_offers(main).is_empty()
		var stored_accept := main.call("_card_resolution_entry_by_id", queued_contract_id) as Dictionary
		ok = ok and String(stored_accept.get("contract_response", "")) == "accepted"
		ok = ok and bool(stored_accept.get("public_owner_revealed", false)) and (stored_accept.get("guessers", []) as Array).has(2)
		ok = ok and String(stored_accept.get("contract_result_clue", "")).contains("合约已签约")
		ok = ok and String(stored_accept.get("contract_accept_summary", "")).contains("流通")
		ok = ok and String(stored_accept.get("aftermath_clue", "")).contains("发起者和回应者仍需推理")
		var districts_after_accept := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		var source_district := districts_after_accept[source_index] as Dictionary
		var target_district := districts_after_accept[target_index] as Dictionary
		var source_city := source_district.get("city", {}) as Dictionary
		var target_city := target_district.get("city", {}) as Dictionary
		ok = ok and ((source_district.get("products", []) as Array).has(product_name) or _test_city_product_names(source_city).has(product_name))
		ok = ok and ((target_district.get("demands", []) as Array).has(product_name) or _test_city_demand_names(target_city).has(product_name))
		var players_after_accept := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		ok = ok and int((players_after_accept[target_owner] as Dictionary).get("cash", 0)) > target_cash_before
		ok = ok and float(target_city.get("route_flow_multiplier", 1.0)) > 1.0

		var decline_skill := main.call("_make_skill", "区域供需合约2") as Dictionary
		var decline_entry := entry.duplicate(true)
		decline_entry["resolution_id"] = 90002
		decline_entry["skill"] = decline_skill.duplicate(true)
		decline_entry["contract_response"] = "pending"
		var players_before_decline := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var decline_cash_before := int((players_before_decline[target_owner] as Dictionary).get("cash", 0))
		ok = ok and bool((contract_controller.call("open_offer", decline_skill, decline_entry) as Dictionary).get("opened", false))
		ok = ok and _contract_pending_offers(main).size() == 1
		ok = ok and bool((contract_controller.call("respond_to_offer", target_owner, 90002, false, false) as Dictionary).get("committed", false))
		var players_after_decline := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		ok = ok and int((players_after_decline[target_owner] as Dictionary).get("cash", 0)) < decline_cash_before
		var districts_after_decline := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts)
		var declined_city := ((districts_after_decline[target_index] as Dictionary).get("city", {}) as Dictionary)
		ok = ok and int(declined_city.get("trade_route_damage", 0)) >= 1

		var timeout_entry := entry.duplicate(true)
		timeout_entry["resolution_id"] = 90003
		timeout_entry["skill"] = decline_skill.duplicate(true)
		timeout_entry["contract_response"] = "pending"
		var players_before_timeout := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		var timeout_cash_before := int((players_before_timeout[target_owner] as Dictionary).get("cash", 0))
		ok = ok and bool((contract_controller.call("open_offer", decline_skill, timeout_entry) as Dictionary).get("opened", false))
		contract_controller.call("tick_visible_offer", 5.1, "contract_response_90003")
		ok = ok and _contract_pending_offers(main).is_empty()
		var players_after_timeout := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		ok = ok and int((players_after_timeout[target_owner] as Dictionary).get("cash", 0)) < timeout_cash_before
		var ai_entry := entry.duplicate(true)
		var punitive_skill := main.call("_make_skill", "惩罚性拒签条款1") as Dictionary
		ai_entry["resolution_id"] = 90004
		ai_entry["skill"] = punitive_skill.duplicate(true)
		ai_entry["contract_response"] = "pending"
		var ai_samples_before := _ai_decision_sample_count(_as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players))
		ok = ok and bool((contract_controller.call("open_offer", punitive_skill, ai_entry) as Dictionary).get("opened", false))
		ok = ok and _contract_pending_offers(main).size() == 1
		var ai_contract_responses := int(_ai_controller(main).call("_update_ai_contract_responses", true))
		ok = ok and ai_contract_responses == 1 and _contract_pending_offers(main).is_empty()
		var players_after_ai_contract := _as_array(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
		ok = ok and _ai_decision_sample_count(players_after_ai_contract) > ai_samples_before
		ok = ok and _ai_memory_has_kind_with_metadata(players_after_ai_contract, target_owner, "匿名合约签约", "policy_kind", "contract_accept")
		ok = ok and _ai_memory_has_kind_with_metadata(players_after_ai_contract, target_owner, "匿名合约签约", "contract_response_role", "accept_avoid_punishment")
		ok = ok and _ai_memory_has_kind_with_metadata(players_after_ai_contract, target_owner, "匿名合约签约", "contract_source_district", source_index)
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	main.free()
	if FileAccess.file_exists(fixture_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_save_path))
	return ok


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _start_smoke_progress_log() -> void:
	_smoke_start_msec = Time.get_ticks_msec()
	var absolute_path := ProjectSettings.globalize_path(SMOKE_PROGRESS_PATH)
	if FileAccess.file_exists(SMOKE_PROGRESS_PATH):
		DirAccess.remove_absolute(absolute_path)
	_mark_smoke_progress("progress log ready")


func _mark_smoke_progress(label: String) -> void:
	if _smoke_start_msec <= 0:
		_smoke_start_msec = Time.get_ticks_msec()
	var elapsed_seconds := float(Time.get_ticks_msec() - _smoke_start_msec) / 1000.0
	var line := "%.2fs｜%s\n" % [elapsed_seconds, label]
	var file := FileAccess.open(SMOKE_PROGRESS_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(SMOKE_PROGRESS_PATH, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_string(line)
		file = null
	print("SMOKE: %s" % line.strip_edges())


func _finish() -> void:
	if _failures.is_empty():
		_cleanup_test_save()
		print("Space Syndicate smoke test passed.")
		quit(0)
	else:
		_cleanup_test_save()
		printerr("Space Syndicate smoke test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)


func _cleanup_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_RUN_SAVE_PATH)
	if FileAccess.file_exists(TEST_RUN_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)
