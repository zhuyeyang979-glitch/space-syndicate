extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const MAP_VIEW_SCRIPT_PATH := "res://scripts/map_view.gd"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const MONSTER_ART_SCRIPT_PATH := "res://scripts/monster_art_view.gd"
const TEST_RUN_SAVE_PATH := "user://space_syndicate_smoke_test_run.save"
const EXPECTED_PLAYER_COUNT := 4
const EXPECTED_AI_PLAYER_COUNT := 3
const EXPECTED_SUMMONED_MONSTER_COUNT := 4
const MIN_REGION_COUNT := 6
const MAX_REGION_COUNT := 54

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_save()
	var packed := load(MAIN_SCENE_PATH)
	_expect(packed is PackedScene, "main scene loads as PackedScene")
	if not (packed is PackedScene):
		_finish()
		return

	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	_expect(main is Control, "main scene instantiates as Control")
	main.set("run_save_path", TEST_RUN_SAVE_PATH)
	main.call("_open_main_menu")
	await process_frame
	var load_run_button := main.get("menu_load_run_button") as Button
	var run_save_label := main.get("menu_run_save_label") as Label
	_expect(run_save_label != null and run_save_label.text.contains("暂无"), "main menu reports no saved run in the test slot")
	_expect(load_run_button != null and load_run_button.disabled, "load run button is disabled when no test save exists")
	main.set("configured_player_count", EXPECTED_PLAYER_COUNT)
	main.set("configured_ai_player_count", EXPECTED_AI_PLAYER_COUNT)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	main.call("_new_game")
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
	var initial_run_state := main.call("_capture_run_state") as Dictionary
	_expect(not initial_run_state.has("configured_monster_indices") and not initial_run_state.has("active_monster_indices"), "run saves contain no legacy monster-lineup fields")
	_expect(not initial_run_state.has("current_balance_index"), "run saves contain no pacing-preset field")

	var players := _as_array(main.get("players"))
	var districts := _as_array(main.get("districts"))
	var skill_market := _as_array(main.get("skill_market"))
	var auto_monsters := _as_array(main.get("auto_monsters"))
	var product_market := main.get("product_market") as Dictionary

	_expect(players.size() == EXPECTED_PLAYER_COUNT, "new game creates the configured player count")
	_expect(int(main.get("configured_ai_player_count")) == EXPECTED_AI_PLAYER_COUNT, "new game keeps the configured AI opponent count")
	_expect(_ai_player_count(players) == EXPECTED_AI_PLAYER_COUNT, "new game creates AI seats for the PVE roguelike run")
	_expect(not bool((players[0] as Dictionary).get("is_ai", true)) and bool((players[1] as Dictionary).get("is_ai", false)), "player 1 remains the human/local seat while later seats are AI opponents")
	_expect(((players[1] as Dictionary).get("ai_profile", {}) as Dictionary).has("style") and ((players[1] as Dictionary).get("ai_memory", {}) as Dictionary).has("decision_samples"), "AI seats carry a personality profile and training-memory log")
	var planet_profile := main.call("_roguelike_planet_profile") as Dictionary
	_expect(districts.size() >= int(planet_profile.get("region_min", MIN_REGION_COUNT)) and districts.size() <= int(planet_profile.get("region_max", MAX_REGION_COUNT)), "new game creates the expected roguelike region count")
	_expect(_verify_roguelike_depth_scaling(main), "roguelike challenge depth scales planet size, region count, and cash victory goal")
	_expect(_verify_victory_countdown_rule(main), "hitting the roguelike cash goal starts a saved final countdown before settlement")
	_expect(_regions_start_with_single_goods(main), "land regions start with one produced good and one demanded good before contracts expand them")
	_expect(auto_monsters.is_empty(), "new game starts with no field monsters until monster cards are played")
	var empty_field_event_parts := main.call("_event_target_weight_parts", int(main.get("selected_district"))) as Dictionary
	_expect(int(empty_field_event_parts.get("monster", -1)) == 0, "event targeting handles an empty monster field without a legacy A/B fallback")
	_expect(_players_have_role_cards(main, players), "each player receives an alien syndicate role card")
	_expect(_role_catalog_has_positive_cards(main), "role codex exposes distinct alien cards with positive mechanical benefits")
	_expect(_verify_random_ai_roles_resolve_unique(main), "random AI role setup resolves to public non-duplicate role cards")
	_expect(_role_cards_have_mechanical_passives(players), "role cards carry visible mechanical passive rules")
	_expect(_role_card_art_exposes_runtime_triggers(main), "role-card artwork exposes regional bonus-card, cashflow product cash, and monster-upgrade cash triggers")
	_expect(_verify_role_passive_runtime(main), "role resource-cash, regional bonus-card, and monster-upgrade rewards resolve in play")
	_expect(_verify_ai_card_policy(main), "AI opponents can score cards, anonymously play monster cards, bid in a simultaneous batch, and record candidate training data")
	_expect(_verify_ai_online_learning_policy(main), "AI opponents apply finalized money rewards as per-seat learned policy bonuses for future business, card, contract, and intel choices")
	_expect(_verify_ai_episode_learning_policy(main), "AI opponents backpropagate final roguelike money results into per-seat long-horizon policy learning")
	_expect(_verify_role_intel_and_trace_tools(main), "identity roles and intel cards reveal private city, card-owner, and contract-party clues")
	_expect(_verify_ai_intel_policy(main), "AI opponents can use product clues to mark city owners and wager on anonymous card ownership")
	_expect(_verify_ai_monster_lure_strategy(main), "AI opponents can steer monster-lure cards toward high-value competing cities and record trainable target metadata")
	_expect(_verify_ai_economic_focus_strategy(main), "AI opponents maintain an economic focus product that shapes city expansion, economy-card targets, and training metadata")
	_expect(_verify_ai_strategy_intent_policy(main), "AI opponents switch between grow, defend, and disrupt strategic intents and attach strategy metadata to decisions")
	_expect(_verify_ai_route_plan_policy(main), "AI opponents form multi-step product-route plans that bias build, card, contract, and business choices")
	_expect(_verify_ai_game_phase_policy(main), "AI opponents adapt choices to opening, midgame, endgame, leader, and trailing states")
	_expect(_verify_ai_progresses_run_smoke(main), "AI opponents can first-summon, build, buy, play, earn income, and hand an AI leader into finale countdown")
	_expect(_verify_max_ai_seat_complete_smoke(main), "an eight-seat run with seven AI opponents can open, build, buy, play, settle, and restore cleanly")
	_expect(_starting_cash_matches_role_bonuses(players), "role passives can modify starting cash without touching starter monsters")
	_expect(_starting_monster_cards_match_configured_choices(main, players), "starter monster cards come from independent setup choices, not role-card fingerprints")
	var player_box := main.get("player_box") as VBoxContainer
	_expect(player_box != null and _container_label_text_contains(player_box, "手牌卡面") and _container_label_text_contains(player_box, "资金:"), "player panel keeps the main game view focused on hand cards and compact cash")
	_expect(player_box != null and _container_label_text_contains(player_box, "目标提示"), "player panel shows one concise next-action hint")
	_expect(player_box != null and _container_label_text_contains(player_box, "开局轻引导") and _container_button_text_contains(player_box, "经济总览") and _container_button_text_contains(player_box, "关闭"), "early-run guide shows a dismissible checklist and economy overview shortcut")
	_expect(player_box != null and _container_label_text_contains(player_box, "开局进度") and _container_label_text_contains(player_box, "下一步卡片") and _container_label_text_contains(player_box, "行动：") and _container_label_text_contains(player_box, "为什么：") and _container_label_text_contains(player_box, "入口：") and _container_label_text_contains(player_box, "首召怪兽"), "early-run guide presents progress, structured next-step card, and task cards")
	_expect(player_box != null and _container_button_text_contains(player_box, "新手引导") and _container_button_text_contains(player_box, "游戏规则"), "early-run guide exposes tutorial and rules shortcuts")
	_expect(player_box != null and _container_label_text_contains(player_box, "当前下一步") and _container_label_text_contains(player_box, "□ 打开经济总览"), "early-run guide shows the real next step and leaves economy overview unchecked before it is opened")
	main.call("_open_economy_overview_menu")
	main.call("_close_menu")
	main.call("_refresh_ui")
	player_box = main.get("player_box") as VBoxContainer
	_expect(player_box != null and _container_label_text_contains(player_box, "✓ 打开经济总览"), "early-run guide checks off economy overview only after opening it")
	var seen_guide_state := main.call("_capture_run_state") as Dictionary
	main.set("opening_guide_economy_seen_players", {})
	_expect(int(main.call("_apply_run_state", seen_guide_state)) == OK and bool(main.call("_opening_guide_economy_seen", 0)), "early-run guide economy-overview progress persists in run saves")
	main.call("_refresh_ui")
	player_box = main.get("player_box") as VBoxContainer
	main.call("_dismiss_opening_guide")
	main.call("_refresh_ui")
	player_box = main.get("player_box") as VBoxContainer
	_expect(player_box != null and not _container_label_text_contains(player_box, "开局轻引导"), "early-run guide can be dismissed from the main play panel")
	var dismissed_guide_state := main.call("_capture_run_state") as Dictionary
	main.set("opening_guide_dismissed", false)
	_expect(int(main.call("_apply_run_state", dismissed_guide_state)) == OK and bool(main.get("opening_guide_dismissed")), "early-run guide dismissed state persists in run saves")
	main.call("_refresh_ui")
	player_box = main.get("player_box") as VBoxContainer
	_expect(player_box != null and not _container_label_text_contains(player_box, "角色卡") and not _container_label_text_contains(player_box, "经济流水") and not _container_card_art_kind_contains(player_box, "player_role"), "player panel hides role/economy details from the main play screen")
	_expect(player_box != null and _container_label_text_contains(player_box, "首召引导") and _container_button_text_contains(player_box, "在选区首召"), "empty-field player panel prompts the starter monster first summon")
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
	_expect(String(main.call("_card_art_stats", regular_monster_card)).contains("HP") and String(main.call("_card_art_stats", regular_monster_card)).contains("怪区"), "monster-card artwork prints HP, duration, movement, and region access")
	_expect(_all_monster_cards_have_field_attributes(main), "every monster card rank defines HP, movement, duration, and summon-region attributes")
	_expect(bool(main.call("_assert_ranked_action_weights_escalate", 0)), "rank-IV monster cards tilt auto-action weights toward later dangerous skills")
	var regular_summon_rejected := not bool(main.call("_summon_monster_from_card", players[0] as Dictionary, regular_monster_card))
	_expect(regular_summon_rejected and _as_array(main.get("auto_monsters")).is_empty(), "post-start monster cards cannot summon outside a landed or adjacent monster region")
	_expect(_verify_monster_card_terrain_restriction(main, players, districts), "terrain-restricted monster cards reject the wrong land/ocean district even inside a monster zone")
	_expect(not skill_market.is_empty(), "new game creates a card/skill market")
	_expect(product_market != null and not product_market.is_empty() and _product_market_has_prices(product_market), "new game creates priced product market data")
	var status_label := main.get("status_label") as Label
	_expect(status_label != null and status_label.text.contains("天气:") and status_label.text.contains("预报:"), "top status bar exposes active weather and the next public forecast")
	var weather_active_label := main.get("weather_active_label") as Label
	var weather_forecast_label := main.get("weather_forecast_label") as Label
	var weather_impact_label := main.get("weather_impact_label") as Label
	_expect(
		weather_active_label != null
		and weather_forecast_label != null
		and weather_impact_label != null
		and weather_active_label.text.contains("现在：")
		and weather_forecast_label.text.contains("预报：")
		and weather_impact_label.text.contains("影响："),
		"main map panel exposes a compact weather forecast strip with current, forecast, and impact text"
	)
	_expect(_verify_weather_forecast_system(main), "planet weather forecasts one to five affected regions 60-180 seconds ahead and then affects GDP modifiers")
	_expect(_verify_news_and_weather_card_rules(main), "news cards are player-made effects while weather-control cards rewrite public forecasts")
	_summon_starting_monsters_for_smoke(main, EXPECTED_SUMMONED_MONSTER_COUNT)
	await process_frame
	players = _as_array(main.get("players"))
	districts = _as_array(main.get("districts"))
	skill_market = _as_array(main.get("skill_market"))
	auto_monsters = _as_array(main.get("auto_monsters"))
	product_market = main.get("product_market") as Dictionary
	_expect(auto_monsters.size() == EXPECTED_SUMMONED_MONSTER_COUNT, "playing starting monster cards summons four anonymous automatic monsters for the smoke run")
	player_box = main.get("player_box") as VBoxContainer
	_expect(player_box != null and not _container_button_text_contains(player_box, "在选区首召"), "first-summon prompt disappears once monsters are on the field")
	var occupied_event_parts := main.call("_event_target_weight_parts", int((auto_monsters[0] as Dictionary).get("position", -1))) as Dictionary
	_expect(int(occupied_event_parts.get("monster", 0)) > 0, "event targeting derives monster attention from the unified automatic-monster collection")
	_expect(_summoned_monsters_have_hidden_owners(auto_monsters), "summoned monster ownership starts hidden while HP and duration are visible")
	_expect(_verify_monster_owner_damage_cash_clue(main), "monster damage cash clues reveal ownership with max-HP proportional losses")
	var first_actor := auto_monsters[0] as Dictionary
	_expect(int(first_actor.get("max_hp", 0)) == int(first_starting_card.get("hp", -1)) and is_equal_approx(float(first_actor.get("duration", 0.0)), float(first_starting_card.get("duration", -1.0))), "starter monster card HP and duration become the summoned monster's field attributes without role overrides")
	_expect(_verify_monster_card_runtime_overrides(main), "summoned monsters read HP, duration, and movement directly from their played card")
	_expect(_verify_field_monster_card_upgrade_refreshes_state(main), "same-name monster cards upgrade an owned field monster and refresh HP, duration, and damage-cash risk")
	_expect(_verify_monster_duration_expiry(main), "a monster automatically leaves when its card field duration expires")
	_expect(_verify_monster_card_play_cash_cost(main), "monster-card play cash cost scales with field monster count and records card spend")
	_expect(_verify_ranked_monster_action_weights(main, first_actor), "summoned higher-rank monsters use rank-tilted auto-action probability weights")
	_expect(_player_has_bound_monster_skill(players, 0), "summoning a monster grants its owner a persistent bound skill card")
	_expect(_player_bound_monster_skill_count(players, 3) >= 1, "summoning grants printed bound monster skills without role-based starter boosts")
	_expect(_verify_bound_monster_skill_persistence(main), "bound monster skills stay in hand and enter cooldown after use")
	_expect(_verify_monster_lure_replaces_control_window(main), "monster lure cards replace old control-window cards with one-shot anonymous movement guidance")
	_expect(_verify_anonymous_cash_card(main), "cash-card public events hide the player who played the card")
	_expect(_verify_anonymous_direct_command(main), "one-shot monster-command events hide the directing player")
	_expect(_verify_remote_supply_access(main), "remote-supply roles and cards extend purchase range without extending monster summon range")
	var queue_results: Dictionary = await _verify_card_resolution_auction_and_guess(main)
	_expect(bool(queue_results.get("five_second_window", false)), "every card enters a five-second public reveal window")
	_expect(bool(queue_results.get("simultaneous_overlay_status", false)), "simultaneous-play overlay explains stage, join window, and bid context")
	_expect(bool(queue_results.get("simultaneous_requirement_visible", false)), "simultaneous-play lobby shows the queued card's public play-requirement snapshot")
	_expect(bool(queue_results.get("bid_status_waiting_visible", false)), "hand bid controls explain the waiting simultaneous-play state")
	_expect(bool(queue_results.get("highest_bid_wins", false)), "highest anonymous bid selects the next resolving card")
	_expect(bool(queue_results.get("auction_overlay_status", false)), "auction overlay explains stage, highest public bid, and bid availability")
	_expect(bool(queue_results.get("bid_status_auction_visible", false)), "hand bid controls explain when a queued card can still raise its public bid")
	_expect(bool(queue_results.get("track_badges_auction_visible", false)), "card track marks the current player's queued card and highest public bids during auction")
	_expect(bool(queue_results.get("clockwise_tie", false)), "equal bids fall back to the clockwise-nearest queued player")
	_expect(bool(queue_results.get("batch_order_locked", false)), "one auction locks the whole batch order without reopening between queued cards")
	_expect(bool(queue_results.get("active_overlay_status", false)), "public reveal overlay explains that new cards enter the next-batch waiting area")
	_expect(bool(queue_results.get("active_overlay_badges_visible", false)), "public reveal overlay shows unknown owner, locked tip, and locked queued count")
	_expect(bool(queue_results.get("active_overlay_requirement_snapshot_visible", false)), "public reveal overlay shows the resolving card's play-requirement snapshot")
	_expect(bool(queue_results.get("active_overlay_my_badge_visible", false)), "public reveal overlay marks the current player's own displayed anonymous card only in that player's view")
	_expect(bool(queue_results.get("active_overlay_animation_visible", false)), "public reveal overlay shows the card's current resolution animation script")
	_expect(bool(queue_results.get("active_overlay_stage_map_effects", false)), "public reveal overlay drives staged card map effects")
	_expect(bool(queue_results.get("card_stage_effect_styles_visible", false)), "card map effects use different visual styles for city, product, and monster cards")
	_expect(bool(queue_results.get("bid_status_locked_visible", false)), "hand bid controls explain when a queued card bid is locked")
	_expect(bool(queue_results.get("track_badges_locked_visible", false)), "card track marks the active reveal and next locked card")
	_expect(bool(queue_results.get("track_requirement_badges_visible", false)), "card track keeps public play-requirement badges on anonymous cards")
	_expect(bool(queue_results.get("track_visual_cues_visible", false)), "card track preserves animation style and map-cue labels for inference")
	_expect(bool(queue_results.get("card_aftermath_clues_visible", false)), "resolved cards leave aftermath clues on map, callout, and history track")
	_expect(bool(queue_results.get("economy_overview_card_aftermath_visible", false)), "economy overview summarizes recent anonymous card aftermath clues")
	_expect(bool(queue_results.get("tip_payment_clues_visible", false)), "card track and economy overview expose anonymous tip-payment clues without revealing owners")
	_expect(bool(queue_results.get("locked_bids_pay_in_sequence", false)), "each queued card pays its locked bid to the previous card owner when its turn begins")
	_expect(bool(queue_results.get("one_shot_leaves_hand_on_queue", false)), "one-shot cards leave the hand as soon as they enter the anonymous card track")
	_expect(bool(queue_results.get("accepts_mid_batch_cards", false)), "a locked resolution batch accepts new cards into a separate next-batch waiting area")
	_expect(bool(queue_results.get("next_batch_track_visible", false)), "the top track shows cards waiting behind the locked batch")
	_expect(bool(queue_results.get("next_batch_save_state", false)), "run-state capture preserves cards waiting for the next batch")
	_expect(bool(queue_results.get("next_batch_single_auction", false)), "all cards submitted during a locked batch enter one auction after that batch clears")
	_expect(bool(queue_results.get("cross_batch_tip_payment", false)), "the first tipped card in a promoted batch pays the previous resolved card owner")
	_expect(bool(queue_results.get("track_records_history", false)), "top card track preserves anonymous resolved-card history")
	_expect(bool(queue_results.get("track_supports_horizontal_drag_scroll", false)), "top card track supports horizontal drag/wheel scrolling")
	_expect(bool(queue_results.get("correct_guess", false)), "correct card-owner guess transfers money and adds a public owner tag")
	_expect(bool(queue_results.get("correct_guess_badge_visible", false)), "correct card-owner guess shows a public owner badge on the card track")
	_expect(bool(queue_results.get("inference_board_public_card_owner_visible", false)), "economy overview inference board summarizes publicly revealed card owners")
	_expect(bool(queue_results.get("inference_board_card_requirement_visible", false)), "economy overview inference board summarizes anonymous card play requirements without scanning rival economies")
	_expect(bool(queue_results.get("wrong_guess", false)), "wrong card-owner guess pays the real owner without revealing them")
	_expect(bool(queue_results.get("wrong_guess_status_visible", false)), "wrong card-owner guess leaves a private guessed status without revealing the owner")
	_expect(bool(queue_results.get("public_logs_anonymous", false)), "auction public logs show bids without naming bidders or recipients")
	_expect(_verify_monster_takeover_resets_owner_clues(main), "monster takeover revokes old bound skills and resets cash clues to the new owner")
	_expect(_economy_ledgers_respect_active_view(main), "economy overview keeps other players' detailed ledgers private")
	players = _as_array(main.get("players"))
	_expect(_product_market_float(product_market, "环晶电池", "growth_multiplier") >= 1.3, "mechanical Jack applies a positive product-growth economy weather at new game start")
	_expect(_product_market_float(product_market, "环晶电池", "route_flow_multiplier") >= 1.35, "mechanical Jack applies a positive route-flow economy weather at new game start")
	var basic_card_price := int(main.call("_card_price", "移动1"))
	var premium_card_price := int(main.call("_card_price", "垄断协议1"))
	var first_monster_card := String(main.call("_monster_card_name", 0, 1))
	_expect(String(main.call("_card_display_name", "怪兽·尸套龙4")).contains("IV级") and not String(main.call("_card_display_name", "怪兽·尸套龙4")).contains("Lv"), "visible card names use Roman-numeral rank text without legacy Lv labels")
	_expect(premium_card_price > basic_card_price, "card prices rise with the card's economic power cost")
	_expect(int(main.call("_card_price", "价格套利2")) == int(main.call("_card_price", "价格套利1")), "higher-rank economy cards keep the same rank-I base price")
	_expect(int(main.call("_card_price", "短期订单2")) == int(main.call("_card_price", "短期订单1")), "temporary contract upgrades keep the same rank-I base price")
	_expect(int(main.call("_card_price", "远期采购2")) == int(main.call("_card_price", "远期采购1")), "product contract upgrades keep the same rank-I base price")
	var growth_strategy_text := String(main.call("_card_strategy_summary", main.call("_make_skill", "城市融资1")))
	var speculation_strategy_text := String(main.call("_card_strategy_summary", main.call("_make_skill", "城市做空1")))
	var intel_strategy_text := String(main.call("_card_strategy_summary", main.call("_make_skill", "业主透镜1")))
	var monster_strategy_text := String(main.call("_card_strategy_summary", main.call("_make_skill", first_monster_card)))
	var growth_budget_text := String(main.call("_card_strength_budget_text", "城市融资1", main.call("_make_skill", "城市融资1")))
	var monster_budget_text := String(main.call("_card_strength_budget_text", first_monster_card, main.call("_make_skill", first_monster_card)))
	_expect(growth_strategy_text.contains("城市成长") and speculation_strategy_text.contains("金融投机") and intel_strategy_text.contains("情报推理") and monster_strategy_text.contains("怪兽路线"), "card strategy summaries are derived for economy, speculation, intel, and monster routes")
	_expect(growth_budget_text.contains("强度预算") and growth_budget_text.contains("主强度") and growth_budget_text.contains("制衡") and monster_budget_text.contains("怪兽"), "card strength budgets explain power drivers and counterplay from data fields")
	_expect(_verify_development_route_balance_baseline(main), "card pool exposes five AI-readable development routes with card coverage, rank ladders, and profile preferences")
	_expect(_verify_ten_hour_route_pack(main), "ten-hour route pack adds complete repair, lockdown, intel-bounty, and route-weather ladders with AI-readable fields")
	_expect(String(main.call("_card_art_stats", main.call("_make_skill", "城市融资1"))).contains("城市成长"), "card face stats show the strategy route for non-monster cards")
	_expect(int(main.call("_card_price", first_monster_card)) > basic_card_price, "monster cards have priced card faces in the shared card economy")
	_expect(_verify_card_codex_uses_unified_categories(main), "card codex treats monster cards as cards and browses them through subcategories")
	_expect(_verify_area_trade_contract_card_variants(main), "area contract card families cover selected, fixed, auto, multi-product, and punitive terms")
	_expect(String(main.call("_card_price_tier_text", premium_card_price)) == "进阶档", "card price maps into an explicit displayed price tier")
	_expect(_verify_monster_region_card_pricing(main), "monster landing regions discount card purchases while adjacent regions keep base price")
	_expect(_verify_reacquired_card_upgrade_rules(main), "reacquiring an owned card upgrades its family and stops at rank IV")
	_expect(_verify_private_discard_purchase_flow(main), "full-hand purchases require a private discard choice without leaking hand size, card names, or discard details")
	_expect(_verify_card_rank_ladders_are_complete(main), "all base card families expose non-regressing I-IV rank ladders at the rank-I price")
	_expect(_verify_playable_card_resolution_coverage(main), "all codex cards and generated monster fixed-skill cards have concrete resolution handlers")
	_expect(_all_card_supply_entries_are_base_rank(main, districts), "card supplies and codex indexes offer base copies while upgrades happen through hand merging")
	_expect(_verify_cards_have_no_legacy_runtime_fields(main), "card objects and run saves no longer expose legacy charge/control fields")
	_expect(_all_districts_have_four_to_five_cards(districts), "each district receives four to five available cards")
	_expect(_all_district_cards_have_sources(districts), "district card choices track their source")
	_expect(_has_monster_card_source(districts), "monster cards are explicitly mixed into district card supplies")
	_expect(_as_array(main.get("movement_trails")).size() > 0, "summoning starting monsters creates visible summon trails")
	_expect(_log_contains(main, "区域补给网完成"), "new game announces card pool generation")

	var terrain_counts := _count_terrain(districts)
	_expect(int(terrain_counts.get("land", 0)) > 0, "generated planet includes land regions")
	_expect(int(terrain_counts.get("ocean", 0)) > 0, "generated planet includes ocean regions")

	var selected_district := int(main.get("selected_district"))
	_expect(selected_district >= 0 and selected_district < districts.size(), "selected district is inside the generated map")
	_expect(main.get("map_view") is Control, "main map view is built")
	_expect(main.get("full_map_view") is Control, "fullscreen map view is built")
	_expect(_map_view_uses_unified_monster_markers(), "map view no longer exposes legacy A/B monster position state")
	_verify_globe_projection_interaction(main, selected_district)
	_verify_selected_district_card_interaction(main, selected_district)

	var buildable_district := _first_buildable_land_district(districts)
	_expect(buildable_district >= 0, "generated planet includes a buildable land district")
	if buildable_district >= 0:
		_verify_monster_resource_and_collision_system(main, buildable_district)
		await process_frame
		main.set("selected_player", 0)
		main.set("selected_district", buildable_district)
		main.call("_build_city_in_selected_district")
		await process_frame
		_expect(int(main.call("_player_active_city_count", 0)) == 1, "city build action creates an active city for player 1")
		_expect(_city_has_single_goods(main, buildable_district), "newly urbanized cities start with one produced good and one demanded good")
		_expect(_map_effects_contain(main, "city_rise"), "city build action emits a temporary city-rise map animation")
		_expect(_player_ledger_contains(_as_array(main.get("players")), 0, "建城支出"), "city build action records an economy ledger spend")
		_expect(_verify_card_play_flow_gate_and_one_shot(main, buildable_district), "playing one-shot cards requires city product flow, does not consume it, and removes the card")
		var rival_city_count_before := _rival_active_city_count(main, 0)
		var rival_cash_before := _rival_cash_total(_as_array(main.get("players")), 0)
		var auto_expansions := int(main.call("_auto_expand_rival_syndicates", true))
		await process_frame
		var rival_city_count_after := _rival_active_city_count(main, 0)
		var players_after_auto_expand := _as_array(main.get("players"))
		_expect(auto_expansions > 0, "forced rival auto expansion creates at least one anonymous city")
		_expect(rival_city_count_after > rival_city_count_before, "rival auto expansion increases non-active-player city count")
		_expect(_rival_cash_total(players_after_auto_expand, 0) < rival_cash_before, "rival auto expansion spends hidden rival funds")
		_expect(_ai_decision_sample_count(players_after_auto_expand) > 0, "AI city expansion records decision samples for later training")
		_expect(_verify_area_trade_contract_accept_and_decline(main), "area trade contracts open a separate non-blocking five-second decision window after reveal and resolve accept, reject, and timeout effects")
		_expect(int(main.call("_player_active_city_count", 0)) == 1, "rival auto expansion does not create a city for the active player")
		_expect(_city_markers_include_unknown_rival(main), "active player's map marks rival auto-expanded cities as unknown owners")
		var rival_city_index := _first_rival_city_index(main, 0)
		_expect(rival_city_index >= 0, "rival auto expansion leaves an identifiable rival city for inference testing")
		if rival_city_index >= 0:
			var districts_for_guess := _as_array(main.get("districts"))
			var rival_city := (districts_for_guess[rival_city_index] as Dictionary).get("city", {}) as Dictionary
			var real_owner := int(rival_city.get("owner", -1))
			var money_before_guess := int(main.call("_player_final_score", 0))
			main.set("selected_player", 0)
			main.set("selected_district", rival_city_index)
			main.set("selected_guess_player", real_owner)
			main.call("_mark_selected_city_guess")
			await process_frame
			_expect(int(main.call("_player_intel_cash", 0)) == 120, "correct private city-owner guess creates intelligence cash reward")
			_expect(int(main.call("_player_final_score", 0)) == money_before_guess + 120, "final settlement money includes intelligence reward")
		var rival_cash_before_business := _rival_cash_total(players_after_auto_expand, 0)
		var business_actions := int(main.call("_auto_rival_business_actions", true))
		await process_frame
		var players_after_business := _as_array(main.get("players"))
		_expect(business_actions > 0, "forced rival business actions create public inference clues")
		_expect(_rival_cash_total(players_after_business, 0) < rival_cash_before_business, "rival business actions spend hidden rival operating funds")
		_expect(_ai_decision_sample_count(players_after_business) > _ai_decision_sample_count(players_after_auto_expand), "AI business actions add more decision samples")
		_expect(_city_public_clue_exists(main), "rival business actions leave public clues on city records")
		_expect(_city_public_clue_history_exists(main), "city public clue history keeps recent anonymous business and contract evidence")
		var cash_after_build := _player_cash(_as_array(main.get("players")), 0)
		main.call("_market_tick")
		main.call("_settle_city_cashflow_seconds", 60.0)
		await process_frame
		var players_after_market := _as_array(main.get("players"))
		_expect(_player_cash(players_after_market, 0) > cash_after_build, "global market refresh plus realtime cashflow pays city income")
		_expect(int((players_after_market[0] as Dictionary).get("last_cashflow_income", 0)) > 0, "realtime cashflow records income since the last global refresh")
		_expect(_as_array((players_after_market[0] as Dictionary).get("cash_history", [])).size() >= 3, "player cash history records spending and income changes")
		_expect(_player_ledger_contains(players_after_market, 0, "城市收入"), "realtime cashflow records city income in the economy ledger")
		_verify_economy_card_effects(main, buildable_district)
		var score_after_build := int(main.call("_player_final_score", 0))
		_expect(int(main.call("_save_run")) == OK, "current run can be saved")
		main.call("_open_main_menu")
		await process_frame
		_expect(run_save_label != null and run_save_label.text.contains("可读取"), "main menu reports a readable saved run in the test slot")
		_expect(load_run_button != null and not load_run_button.disabled, "load run button is enabled when the test save is readable")
		main.call("_new_game")
		await process_frame
		_expect(int(main.call("_player_active_city_count", 0)) == 0, "new game clears saved-run city state before load")
		var load_result := int(main.call("_load_run"))
		var loaded_score_immediately := int(main.call("_player_final_score", 0))
		_expect(load_result == OK, "current run can be loaded")
		await process_frame
		_expect(_players_have_role_cards(main, _as_array(main.get("players"))), "loaded run restores player role cards")
		_expect(_as_array(main.get("auto_monsters")).size() == EXPECTED_SUMMONED_MONSTER_COUNT, "loaded run restores summoned field monsters")
		_expect(int(main.call("_player_active_city_count", 0)) == 1, "loaded run restores built city assets")
		_expect(loaded_score_immediately == score_after_build, "loaded run restores the saved player score")

	var menu_overlay := main.get("menu_overlay") as Control
	_expect(menu_overlay != null and menu_overlay.visible, "main menu overlay opens after setup")
	var menu_title_label := main.get("menu_title_label") as Label
	var menu_context_label := main.get("menu_context_label") as Label
	var menu_body_label := main.get("menu_body_label") as Label
	var menu_back_button := main.get("menu_back_button") as Button
	var menu_continue_button := main.get("menu_continue_button") as Button
	var menu_quick_nav_row := main.get("menu_quick_nav_row") as HBoxContainer
	var menu_interaction_hint_panel := main.get("menu_interaction_hint_panel") as PanelContainer
	var menu_interaction_hint_label := main.get("menu_interaction_hint_label") as Label
	var menu_bestiary_prev_button := main.get("menu_bestiary_prev_button") as Button
	var menu_bestiary_next_button := main.get("menu_bestiary_next_button") as Button
	var menu_preview_box := main.get("menu_preview_box") as VBoxContainer
	var menu_surface_panel := main.get("menu_surface_panel") as PanelContainer
	var menu_content_scroll := main.get("menu_content_scroll") as ScrollContainer
	var menu_content_box := main.get("menu_content_box") as VBoxContainer
	main.call("_open_main_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "太空辛迪加", "main menu opens with the root title")
	_expect(menu_context_label != null and menu_context_label.text.contains("当前位置：主菜单") and menu_context_label.text.contains("hover"), "main menu exposes a reusable breadcrumb/help strip for flexible subpage navigation")
	_expect(menu_interaction_hint_panel != null and menu_interaction_hint_panel.has_theme_stylebox_override("panel") and menu_interaction_hint_label != null and menu_interaction_hint_label.text.contains("响应式主菜单") and menu_interaction_hint_label.text.contains("分区卡片网格") and menu_interaction_hint_label.text.contains("自动重排") and menu_interaction_hint_label.text.contains("hover"), "main menu exposes a reusable interaction hint strip for responsive card-grid layout, hover, and future menu rearrangement")
	_expect(menu_quick_nav_row != null and menu_quick_nav_row.visible and _container_button_text_contains(menu_quick_nav_row, "开局") and _container_button_text_contains(menu_quick_nav_row, "经济") and _container_button_text_contains(menu_quick_nav_row, "情报") and _container_button_text_contains(menu_quick_nav_row, "图鉴"), "main menu exposes reusable quick navigation chips for major branches")
	_expect(menu_surface_panel != null and menu_surface_panel.has_theme_stylebox_override("panel") and menu_surface_panel.custom_minimum_size.x >= 760.0, "main menu uses a reusable responsive surface panel")
	_expect(menu_content_scroll != null and not menu_content_scroll.follow_focus and menu_content_box != null and menu_preview_box != null and menu_preview_box.get_parent() == menu_content_box, "main menu keeps body and previews inside a scrollable content column without focus-jumping on hover")
	_expect(menu_overlay != null and _container_has_meta(menu_overlay, "main_menu_action_grid") and _container_has_meta(menu_overlay, "main_menu_grid_card"), "main menu arranges branch entries as reusable responsive card grids")
	_expect(menu_body_label != null and menu_body_label.text.contains("怪兽牌"), "main menu points new games to the monster-card start flow")
	_expect(menu_body_label != null and menu_body_label.text.contains("游戏规则") and not menu_body_label.text.contains("快捷键："), "main menu keeps detailed controls inside the rules branch")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "主菜单速览") and _container_label_text_contains(menu_preview_box, "主画面原则") and _container_label_text_contains(menu_preview_box, "终局复盘"), "main menu exposes compact responsive summary cards above the detailed action branches")
	_expect(menu_overlay != null and _container_button_text_contains(menu_overlay, "开局准备"), "main menu routes new games through a setup preview branch")
	_expect(menu_overlay != null and _container_label_text_contains(menu_overlay, "设置3-8席") and _container_label_text_contains(menu_overlay, "hover预览"), "main menu uses descriptive card-style action entries")
	_expect(menu_overlay != null and _container_button_has_stylebox(menu_overlay, "hover") and _container_button_has_stylebox(menu_overlay, "pressed"), "menu buttons expose reusable hover and pressed visual states")
	_expect(menu_overlay != null and _container_button_text_contains(menu_overlay, "情报档案"), "main menu exposes the intel dossier branch")
	_expect(menu_overlay != null and not _container_button_text_contains(menu_overlay, "选择四怪兽"), "main menu no longer exposes a separate monster-selection branch")
	_expect(menu_back_button != null and not menu_back_button.visible, "root menu does not show a redundant back button")
	var player_count_before_setup := int(main.get("configured_player_count"))
	var role_indices_before_setup := _as_array(main.get("configured_role_indices")).duplicate(true)
	if role_indices_before_setup.is_empty():
		main.call("_ensure_configured_role_indices")
		role_indices_before_setup = _as_array(main.get("configured_role_indices")).duplicate(true)
	var current_players_before_setup := _as_array(main.get("players")).size()
	main.call("_start_new_run_from_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "开局准备", "new-run entry opens the setup preview instead of immediately starting")
	_expect(menu_context_label != null and menu_context_label.text.contains("主菜单 → 开局准备"), "setup branch updates the breadcrumb/help strip")
	_expect(_as_array(main.get("players")).size() == current_players_before_setup, "opening setup preview does not wipe the current run")
	_expect(menu_body_label != null and menu_body_label.text.contains("角色卡") and menu_body_label.text.contains("起始怪兽牌"), "new-run setup explains role cards and starter monster cards")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "开始本局"), "new-run setup requires an explicit start confirmation")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "角色被动"), "new-run setup previews role passive rules")
	_expect(menu_preview_box != null and _container_card_art_kind_contains(menu_preview_box, "player_role"), "new-run setup previews player role-card art")
	_expect(menu_preview_box != null and _container_card_art_kind_contains(menu_preview_box, "monster_card"), "new-run setup previews starter monster-card art")
	_expect(menu_preview_box != null and _container_card_art_stats_contains(menu_preview_box, "不限区"), "new-run setup starter card art shows the unrestricted first-summon access")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "固定技能") and _container_label_text_contains(menu_preview_box, "开放购牌"), "new-run setup explains starter summon rewards and card-access radius")
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
	_expect(int(main.get("configured_ai_player_count")) == 7 and menu_preview_box != null and _container_label_text_contains(menu_preview_box, "AI对手7"), "new-run setup can configure a 3-8 seat PVE run with 2-7 AI opponents")
	main.call("_set_configured_player_count_from_new_game_menu", player_count_before_setup)
	await process_frame
	main.call("_set_configured_ai_player_count_from_new_game_menu", EXPECTED_AI_PLAYER_COUNT)
	await process_frame
	main.set("configured_role_indices", role_indices_before_setup)
	main.call("_ensure_configured_role_indices")
	main.call("_open_main_menu")
	await process_frame
	main.call("_open_tutorial_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "新手引导", "tutorial menu opens from the main scene")
	_expect(menu_back_button != null and menu_back_button.visible, "tutorial subpage exposes a visible return-to-main button")
	_expect(menu_continue_button != null and menu_continue_button.visible, "tutorial subpage still lets the player continue the game")
	_expect(menu_body_label != null and menu_body_label.text.contains("秘密城市化"), "tutorial explains the secret city loop")
	_expect(menu_body_label != null and menu_body_label.text.contains("I级基础价") and not menu_body_label.text.contains("Lv"), "tutorial describes rank-I base-price card upgrades with Roman-numeral ranks")
	main.call("_open_rules_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "游戏规则", "rules menu opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("I级基础价") and menu_body_label.text.contains("IV级") and not menu_body_label.text.contains("Lv"), "rules menu explains rank-I base prices and rank-IV caps with Roman-numeral ranks")
	_expect(menu_body_label != null and menu_body_label.text.contains("一次性普通牌") and menu_body_label.text.contains("立刻离开手牌") and menu_body_label.text.contains("卡牌快照"), "rules menu documents one-shot cards leaving hand as soon as they enter the anonymous track")
	_expect(menu_body_label != null and menu_body_label.text.contains("最大生命值损失比例"), "rules menu explains monster ownership cash clues use max-HP proportional losses")
	_expect(menu_body_label != null and menu_body_label.text.contains("不提供1x/2x/4x时间倍率") and menu_body_label.text.contains("操作入口索引") and not menu_body_label.text.contains("Y切预设"), "rules menu removes player-facing time-multiplier presets and centralizes controls")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "规则速览") and _container_label_text_contains(menu_preview_box, "先召怪兽") and _container_label_text_contains(menu_preview_box, "匿名出牌"), "rules menu exposes a compact card-summary layer above the long rule text")
	var quick_nav_buttons := main.get("menu_quick_nav_buttons") as Dictionary
	var rules_quick_button := quick_nav_buttons.get("rules", null) as Button
	var economy_quick_button := quick_nav_buttons.get("economy", null) as Button
	_expect(rules_quick_button != null and rules_quick_button.disabled and economy_quick_button != null and not economy_quick_button.disabled, "quick navigation marks the current rules page while leaving other branches available")
	if economy_quick_button != null:
		economy_quick_button.emit_signal("pressed")
		await process_frame
		_expect(menu_title_label != null and menu_title_label.text == "经济总览", "quick navigation can jump directly from rules to economy overview")
	main.call("_open_standings_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "局势排名", "standings menu opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("预估结算资金"), "standings menu explains estimated settlement money")
	_expect(menu_body_label != null and menu_body_label.text.contains("公开异动") and menu_body_label.text.contains("对手计划、现金和手牌保持隐藏") and not menu_body_label.text.contains("AI对局压力") and not menu_body_label.text.contains("反制建议") and not menu_body_label.text.contains("推荐卡牌路线"), "standings menu shows only public situation clues and hides AI route/bucket data")
	_expect(menu_body_label != null and menu_body_label.text.contains("情报待结算"), "standings keeps intelligence cash pending until final settlement")
	_expect(menu_body_label != null and menu_body_label.text.contains("存活城市1×"), "standings menu reflects built city assets")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "局势速览") and _container_label_text_contains(menu_preview_box, "终局条件") and _container_label_text_contains(menu_preview_box, "我的可见资金"), "standings menu exposes compact victory and cash summary cards")
	main.call("_open_economy_overview_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "经济总览", "economy overview opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("情报现金只在终局兑现"), "economy overview avoids revealing intelligence correctness early")
	_expect(menu_body_label != null and menu_body_label.text.contains("商品热榜") and menu_body_label.text.contains("低价/供给压制"), "economy overview shows product price gradients")
	_expect(menu_body_label != null and menu_body_label.text.contains("商路收入前景") and menu_body_label.text.contains("玩家经济隐私"), "economy overview shows route prospects while keeping rival economics private")
	_expect(menu_body_label != null and menu_body_label.text.contains("公开异动") and menu_body_label.text.contains("对手计划、现金和手牌保持隐藏") and not menu_body_label.text.contains("AI对局压力") and not menu_body_label.text.contains("公开路线观察") and not menu_body_label.text.contains("推荐卡牌路线"), "economy overview shows public results while hiding AI route/bucket data")
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
	menu_preview_box = main.get("menu_preview_box") as VBoxContainer
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "查看区域线索"), "intel dossier exposes region clue jump buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "查看卡牌线索"), "intel dossier exposes card clue jump buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "标玩家") and _container_button_text_contains(menu_preview_box, "清除"), "intel dossier exposes city-owner mark buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "卡牌条件") and _container_button_text_contains(menu_preview_box, "怪兽资金"), "intel dossier exposes city-owner mark reason buttons")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "打开经济总览"), "intel dossier keeps an economy overview jump")
	var dossier_rival_city_index := _first_rival_city_index(main, 0)
	if dossier_rival_city_index >= 0:
		main.call("_mark_city_guess_from_intel", dossier_rival_city_index, -1)
		await process_frame
		var players_after_intel_clear := _as_array(main.get("players"))
		var guesses_after_intel_clear := (players_after_intel_clear[0] as Dictionary).get("city_guesses", {}) as Dictionary
		_expect(not guesses_after_intel_clear.has(dossier_rival_city_index), "intel dossier can clear a private city-owner mark")
		main.call("_mark_city_guess_from_intel", dossier_rival_city_index, 1)
		await process_frame
		var players_after_intel_mark := _as_array(main.get("players"))
		var guesses_after_intel_mark := (players_after_intel_mark[0] as Dictionary).get("city_guesses", {}) as Dictionary
		_expect(int(guesses_after_intel_mark.get(dossier_rival_city_index, -1)) == 1, "intel dossier can update a private city-owner mark")
		main.call("_set_city_guess_confidence_from_intel", dossier_rival_city_index, 3)
		await process_frame
		var players_after_confidence := _as_array(main.get("players"))
		var confidence_after_intel := (players_after_confidence[0] as Dictionary).get("city_guess_confidence", {}) as Dictionary
		_expect(int(confidence_after_intel.get(dossier_rival_city_index, 0)) == 3, "intel dossier can update city-owner mark confidence")
		_expect(menu_body_label != null and menu_body_label.text.contains("置信:高") and menu_body_label.text.contains("置信分布"), "intel dossier displays city-owner mark confidence")
		main.call("_set_city_guess_reason_from_intel", dossier_rival_city_index, "card")
		await process_frame
		var players_after_reason := _as_array(main.get("players"))
		var reasons_after_intel := (players_after_reason[0] as Dictionary).get("city_guess_reasons", {}) as Dictionary
		_expect(String(reasons_after_intel.get(dossier_rival_city_index, "")) == "card", "intel dossier can update city-owner mark reason")
		_expect(menu_body_label != null and menu_body_label.text.contains("理由:卡牌条件") and menu_body_label.text.contains("理由分布"), "intel dossier displays city-owner mark reason")
		var intel_city_entries := _as_array(main.call("_intel_city_guess_entries", 0, 6))
		_expect(not intel_city_entries.is_empty() and int((intel_city_entries[0] as Dictionary).get("priority", -1)) >= 0, "intel dossier computes non-negative city investigation priority")
		var intel_save_state := main.call("_capture_run_state") as Dictionary
		var intel_save_players := _as_array(intel_save_state.get("players", []))
		var saved_confidence := (intel_save_players[0] as Dictionary).get("city_guess_confidence", {}) as Dictionary
		var saved_reasons := (intel_save_players[0] as Dictionary).get("city_guess_reasons", {}) as Dictionary
		_expect(int(saved_confidence.get(dossier_rival_city_index, 0)) == 3, "run-state capture preserves city-owner mark confidence")
		_expect(String(saved_reasons.get(dossier_rival_city_index, "")) == "card", "run-state capture preserves city-owner mark reason")
	main.call("_open_intel_region_codex_link", buildable_district)
	await process_frame
	var intel_back_button := main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "区域图鉴" and intel_back_button != null and intel_back_button.text == "返回情报档案", "intel dossier region links return to the dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "region codex returns to the intel dossier")
	main.call("_open_intel_card_codex_link", "城市融资1")
	await process_frame
	intel_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴" and intel_back_button != null and intel_back_button.text == "返回缩略图", "intel dossier card links open card detail before returning to thumbnails")
	main.call("_back_from_catalog_menu")
	await process_frame
	intel_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴" and menu_body_label != null and menu_body_label.text.contains("缩略图册") and intel_back_button != null and intel_back_button.text == "返回情报档案", "card detail returns to thumbnail page before the intel dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "card thumbnail page returns to the intel dossier")
	main.call("_open_intel_monster_codex_link", 0)
	await process_frame
	intel_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案" and intel_back_button != null and intel_back_button.text == "返回缩略图", "intel dossier monster links open monster detail before returning to thumbnails")
	main.call("_back_from_catalog_menu")
	await process_frame
	intel_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案" and menu_body_label != null and menu_body_label.text.contains("怪兽生态缩略图册") and intel_back_button != null and intel_back_button.text == "返回情报档案", "monster detail returns to thumbnail page before the intel dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "monster thumbnail page returns to the intel dossier")
	main.call("_open_intel_product_codex_link", "活体芯片")
	await process_frame
	intel_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "商品图鉴" and intel_back_button != null and intel_back_button.text == "返回缩略图", "intel dossier product links open product detail before returning to thumbnails")
	main.call("_back_from_catalog_menu")
	await process_frame
	intel_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "商品图鉴" and menu_body_label != null and menu_body_label.text.contains("商品缩略图册") and intel_back_button != null and intel_back_button.text == "返回情报档案", "product detail returns to thumbnail page before the intel dossier")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "情报档案", "product thumbnail page returns to the intel dossier")
	main.call("_open_compendium_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "图鉴", "unified compendium opens from the main scene")
	_expect(menu_body_label != null and menu_body_label.text.contains("角色图鉴") and menu_body_label.text.contains("商品图鉴") and menu_body_label.text.contains("区域图鉴"), "compendium introduces all sub-codex sections")
	menu_preview_box = main.get("menu_preview_box") as VBoxContainer
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "角色图鉴"), "compendium exposes role codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "怪兽生态档案"), "compendium exposes monster ecology dossier")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "卡牌图鉴"), "compendium exposes card codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "商品图鉴"), "compendium exposes product codex")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "区域图鉴"), "compendium exposes region codex")
	players = _as_array(main.get("players"))
	var first_role := (players[0] as Dictionary).get("role_card", {}) as Dictionary
	main.call("_open_role_codex_from_compendium")
	await process_frame
	var menu_bestiary_back_button := main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "角色图鉴", "role codex opens from the compendium")
	_expect(menu_bestiary_back_button != null and menu_bestiary_back_button.text == "返回图鉴", "role codex returns to the compendium")
	_expect(menu_body_label != null and menu_body_label.text.contains("角色卡") and menu_body_label.text.contains("特征") and menu_body_label.text.contains("角色被动") and menu_body_label.text.contains("起始怪兽牌"), "role codex explains role traits, passives, and starter monster cards")
	_expect(menu_preview_box != null and _container_card_art_kind_contains(menu_preview_box, "player_role"), "role codex displays role cards with the shared card-art component")
	_expect(menu_preview_box != null and _container_card_art_stats_contains(menu_preview_box, "公开身份") and not _container_card_art_stats_contains(menu_preview_box, "起始:"), "role codex card art presents public identity without starter-monster fingerprints")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "独立选择") and not _container_button_text_contains(menu_preview_box, "点击查看卡牌图鉴") and not _container_button_text_contains(menu_preview_box, "查看怪兽生态档案"), "role codex does not link roles to starter monster cards")
	var old_role_text := menu_body_label.text
	main.call("_cycle_menu_catalog", 1)
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "角色图鉴" and menu_body_label.text != old_role_text, "role codex next button logic changes pages")
	main.call("_open_bestiary_from_compendium")
	await process_frame
	menu_bestiary_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_title_label != null and menu_title_label.text == "怪兽生态档案", "monster ecology dossier opens from the compendium")
	_expect(menu_overlay != null and not _container_button_text_contains(menu_overlay, "仅查看") and not _container_button_text_contains(menu_overlay, "开局不再预选怪兽"), "monster codex has no hidden legacy lineup controls")
	_expect(menu_bestiary_back_button != null and menu_bestiary_back_button.text == "返回图鉴", "monster thumbnail codex returns to the compendium")
	_expect(menu_body_label != null and menu_body_label.text.contains("怪兽生态缩略图册") and menu_body_label.text.contains("不是另一套怪兽牌图鉴") and menu_body_label.text.contains("当前缩略图布局") and menu_body_label.text.contains("双击缩略图进入怪兽详情"), "monster ecology dossier opens as a responsive thumbnail grid without duplicating monster cards")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "缩略图下一页") and _container_label_text_contains(menu_preview_box, "悬停详情预览"), "monster codex thumbnail page exposes paging and hover preview")
	_expect(menu_bestiary_prev_button != null and not menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and not menu_bestiary_next_button.visible, "monster codex hides detail previous/next buttons on the thumbnail page")
	main.call("_preview_bestiary_entry", 0, true)
	await process_frame
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "HP:") and _container_label_text_contains(menu_preview_box, "行动:"), "monster codex hover preview shows the selected monster details")
	var monster_detail_event := InputEventMouseButton.new()
	monster_detail_event.button_index = MOUSE_BUTTON_LEFT
	monster_detail_event.pressed = true
	monster_detail_event.double_click = true
	main.call("_on_bestiary_thumbnail_gui_input", monster_detail_event, 0)
	await process_frame
	menu_bestiary_back_button = main.get("menu_bestiary_back_button") as Button
	_expect(menu_body_label != null and menu_body_label.text.contains("正面经济天气"), "monster codex shows positive economy abilities")
	_expect(menu_body_label != null and menu_body_label.text.contains("IV级") and menu_body_label.text.contains("权重修正"), "monster codex explains rank-based action probability shifts")
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
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴" and menu_body_label != null and menu_body_label.text.contains("怪兽卡") and menu_body_label.text.contains("生命"), "monster-card link can jump to the matching card codex entry")
	main.call("_open_bestiary_from_compendium")
	await process_frame
	main.call("_open_card_codex_from_compendium")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "卡牌图鉴", "card codex opens from the compendium")
	_expect(menu_interaction_hint_label != null and menu_interaction_hint_label.text.contains("卡牌缩略图") and menu_interaction_hint_label.text.contains("hover") and menu_interaction_hint_label.text.contains("双击进详情"), "card codex thumbnail page exposes the shared hover/detail interaction hint")
	_expect(menu_body_label != null and menu_body_label.text.contains("缩略图册") and menu_body_label.text.contains("当前缩略图布局") and menu_body_label.text.contains("双击缩略图进入卡牌详情"), "card codex opens as a responsive thumbnail grid")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "缩略图下一页") and _container_label_text_contains(menu_preview_box, "悬停详情预览"), "card codex thumbnail page exposes paging and hover preview")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "卡牌路线总览") and _container_label_text_contains(menu_preview_box, "城市成长路线") and _container_label_text_contains(menu_preview_box, "金融投机路线") and _container_label_text_contains(menu_preview_box, "卡牌路线覆盖") and _container_label_text_contains(menu_preview_box, "核心路线5/5覆盖") and _container_label_text_contains(menu_preview_box, "强度区间") and _container_label_text_contains(menu_preview_box, "支点") and _container_label_text_contains(menu_preview_box, "平衡") and _container_label_text_contains(menu_preview_box, "反制") and not _container_label_text_contains(menu_preview_box, "AI发展路线") and not _container_label_text_contains(menu_preview_box, "AI偏好"), "card codex exposes data-driven public strategy route overview cards without AI route leaks")
	_expect(menu_bestiary_prev_button != null and not menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and not menu_bestiary_next_button.visible, "card codex hides detail previous/next buttons on the thumbnail page")
	main.call("_preview_card_codex_card", "城市融资1", true)
	await process_frame
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "城市融资") and _container_label_text_contains(menu_preview_box, "升级梯度"), "card codex hover preview shows the selected card details")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "预算:") and _container_label_text_contains(menu_preview_box, "主强度"), "card codex hover preview shows the field-derived strength budget")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "路线:城市成长"), "card codex hover preview explains the card's strategic route")
	var codex_detail_event := InputEventMouseButton.new()
	codex_detail_event.button_index = MOUSE_BUTTON_LEFT
	codex_detail_event.pressed = true
	codex_detail_event.double_click = true
	main.call("_on_card_codex_thumbnail_gui_input", codex_detail_event, "城市融资1")
	await process_frame
	var card_codex_back_button := main.get("menu_bestiary_back_button") as Button
	_expect(menu_interaction_hint_label != null and menu_interaction_hint_label.text.contains("卡牌详情页") and menu_interaction_hint_label.text.contains("上一页/下一页") and menu_interaction_hint_label.text.contains("返回缩略图"), "card detail page exposes the shared previous/next and return-to-thumbnail interaction hint")
	_expect(menu_body_label != null and menu_body_label.text.contains("参考价") and menu_body_label.text.contains("档"), "card detail shows card price and explicit tier information")
	_expect(menu_body_label != null and menu_body_label.text.contains("按I级基础价") and not menu_body_label.text.contains("Lv"), "card detail labels rank-I base prices with Roman-numeral ranks")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "牌面定位") and _container_label_text_contains(menu_preview_box, "费用与门槛") and _container_label_text_contains(menu_preview_box, "核心效果") and _container_label_text_contains(menu_preview_box, "关键字段"), "card detail uses TCG-style sections for purpose, cost, effect, and key fields")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "I-IV升级梯度") and _container_label_text_contains(menu_preview_box, "预算:"), "card detail shows a structured I-IV level-gradient grid")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "结算演出") and _container_label_text_contains(menu_preview_box, "匿名"), "card detail shows the public anonymous resolution presentation")
	_expect(card_codex_back_button != null and card_codex_back_button.text == "返回缩略图" and menu_bestiary_prev_button != null and menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and menu_bestiary_next_button.visible, "card detail exposes previous/next and a return-to-thumbnails button")
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "匿名投资光幕"), "city economy cards use their own resolution animation script")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_body_label != null and menu_body_label.text.contains("缩略图册"), "card detail can return to the thumbnail grid")
	main.set("selected_trade_product", "活体芯片")
	main.call("_open_product_codex_menu")
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "商品图鉴", "product codex opens from the compendium")
	_expect(menu_body_label != null and menu_body_label.text.contains("商品缩略图册") and menu_body_label.text.contains("当前缩略图布局") and menu_body_label.text.contains("双击缩略图进入商品详情"), "product codex opens as a responsive thumbnail grid")
	_expect(menu_preview_box != null and _container_button_text_contains(menu_preview_box, "缩略图下一页") and _container_label_text_contains(menu_preview_box, "悬停详情预览"), "product codex thumbnail page exposes paging and hover preview")
	_expect(menu_bestiary_prev_button != null and not menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and not menu_bestiary_next_button.visible, "product codex hides detail previous/next buttons on the thumbnail page")
	var product_preview_index := int(main.get("product_codex_index"))
	main.call("_preview_product_codex_entry", product_preview_index, true)
	await process_frame
	_expect(menu_preview_box != null and _container_label_text_contains(menu_preview_box, "活体芯片") and _container_label_text_contains(menu_preview_box, "价格梯度"), "product codex hover preview shows the selected product details")
	var product_detail_event := InputEventMouseButton.new()
	product_detail_event.button_index = MOUSE_BUTTON_LEFT
	product_detail_event.pressed = true
	product_detail_event.double_click = true
	main.call("_on_product_codex_thumbnail_gui_input", product_detail_event, product_preview_index)
	await process_frame
	var product_codex_back_button := main.get("menu_bestiary_back_button") as Button
	_expect(menu_body_label != null and menu_body_label.text.contains("活体芯片"), "product detail opens on the currently selected trade product")
	_expect(menu_body_label != null and menu_body_label.text.contains("价格梯度") and menu_body_label.text.contains("当前价"), "product codex shows product price and tier information")
	_expect(menu_body_label != null and menu_body_label.text.contains("经济天气"), "product codex shows product growth and flow weather")
	_expect(menu_body_label != null and menu_body_label.text.contains("商品相关城市线索"), "product codex can filter city clues by product")
	_expect(product_codex_back_button != null and product_codex_back_button.text == "返回缩略图" and menu_bestiary_prev_button != null and menu_bestiary_prev_button.visible and menu_bestiary_next_button != null and menu_bestiary_next_button.visible, "product detail exposes previous/next and a return-to-thumbnails button")
	main.call("_back_from_catalog_menu")
	await process_frame
	_expect(menu_body_label != null and menu_body_label.text.contains("商品缩略图册"), "product detail can return to the thumbnail grid")
	main.call("_open_region_codex_menu", buildable_district)
	await process_frame
	_expect(menu_title_label != null and menu_title_label.text == "区域图鉴", "region codex opens from the compendium")
	_expect(menu_body_label != null and menu_body_label.text.contains("区域可提供卡牌"), "region codex lists the cards available from a region")
	_expect(menu_body_label != null and menu_body_label.text.contains("真实业主不公开"), "region codex preserves hidden city ownership")
	_expect(menu_body_label != null and menu_body_label.text.contains("流通加速"), "region codex shows city route-flow acceleration status")
	_expect(menu_body_label != null and menu_body_label.text.contains("收入拆解") and menu_body_label.text.contains("生产明细"), "region codex shows city income breakdown details")

	_verify_special_monster_passives(main)
	_verify_card_art_script()
	_verify_monster_art_script()
	if buildable_district >= 0:
		var districts_before_destroy := _as_array(main.get("districts"))
		var built_district := districts_before_destroy[buildable_district] as Dictionary
		var built_city := built_district.get("city", {}) as Dictionary
		if bool(built_city.get("active", false)):
			main.call("_damage_district", buildable_district, int(built_district.get("hp", 10)) + 2, "烟测怪兽践踏")
			await process_frame
			_expect(_map_effects_contain(main, "city_destroyed"), "monster trampling a city emits a temporary city-collapse animation")

	main.queue_free()
	await process_frame
	_finish()


func _verify_selected_district_card_interaction(main: Node, district_index: int) -> void:
	var districts := _as_array(main.get("districts"))
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
	var before_cards := _player_card_names(_as_array(main.get("players")), 0)
	var before_cash := _player_cash(_as_array(main.get("players")), 0)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	main.call("_on_district_card_gui_input", event, card_name)
	var players_after := _as_array(main.get("players"))
	var after_cards := _player_card_names(players_after, 0)
	_expect(after_cards.size() >= before_cards.size(), "double-clicking a district card acquires or upgrades a card")
	_expect(_player_has_card_family(after_cards, card_name), "double-click acquisition leaves the card family in the player's hand")
	_expect(_player_cash(players_after, 0) < before_cash, "double-click district card acquisition spends player funds")
	_expect(_player_total_card_spend(players_after, 0) > 0, "district card acquisition records card spend")
	_expect(_player_ledger_contains(players_after, 0, "卡牌支出"), "district card acquisition records an economy ledger spend")
	_clear_player_cooldown(main, 0)


func _verify_globe_projection_interaction(main: Node, district_index: int) -> void:
	var districts := _as_array(main.get("districts"))
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
	map_view.set("_view_zoom", 1.0)
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
			if String(source_variant).contains("怪兽卡"):
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
		for field_name in ["starting_cash_bonus", "resource_cash_product", "resource_cash_amount", "bonus_card_product", "monster_upgrade_cash", "intel_city_reveal_charges", "intel_card_trace_charges", "intel_contract_trace_charges", "city_guess_reward_bonus", "card_owner_guess_discount", "card_owner_guess_bonus", "contract_flow_discount", "card_access_extra_hops", "card_access_global"]:
			if role.has(field_name):
				has_mechanical_field = true
				break
		if not has_mechanical_field:
			return false
	return not players.is_empty()


func _starting_cash_matches_role_bonuses(players: Array) -> bool:
	if players.is_empty():
		return false
	var baseline := 0
	var saw_cash_bonus := false
	for i in range(players.size()):
		var player := players[i] as Dictionary
		var role := player.get("role_card", {}) as Dictionary
		var bonus := int(role.get("starting_cash_bonus", 0))
		if i == 0:
			baseline = int(player.get("cash", 0)) - bonus
		if int(player.get("cash", 0)) != baseline + bonus:
			return false
		saw_cash_bonus = saw_cash_bonus or bonus > 0
	return baseline > 0 and saw_cash_bonus


func _role_catalog_has_positive_cards(main: Node) -> bool:
	var role_count := int(main.call("_player_role_catalog_size"))
	if role_count < 16:
		return false
	var names := {}
	var has_city_intel_role := false
	var has_card_trace_role := false
	var has_contract_trace_role := false
	var has_remote_supply_role := false
	for role_index in range(role_count):
		var role := main.call("_make_player_role_card", role_index, role_index) as Dictionary
		var role_name := String(role.get("name", ""))
		if role_name == "" or names.has(role_name) or String(role.get("species", "")) == "" or String(role.get("passive", "")) == "":
			return false
		names[role_name] = true
		for starter_field in ["starter_monster_index", "starter_monster_name", "starter_monster_card", "starter_hp_bonus", "starter_duration_bonus", "starter_move_multiplier", "starter_fixed_skill_bonus"]:
			if role.has(starter_field):
				return false
		var has_positive_benefit := int(role.get("starting_cash_bonus", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("resource_cash_amount", 0)) > 0
		has_positive_benefit = has_positive_benefit or String(role.get("bonus_card_product", "")) != ""
		has_positive_benefit = has_positive_benefit or int(role.get("monster_upgrade_cash", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("intel_city_reveal_charges", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("intel_card_trace_charges", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("intel_contract_trace_charges", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("city_guess_reward_bonus", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("card_owner_guess_discount", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("card_owner_guess_bonus", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("contract_flow_discount", 0)) > 0
		has_positive_benefit = has_positive_benefit or int(role.get("card_access_extra_hops", 0)) > 0
		has_positive_benefit = has_positive_benefit or bool(role.get("card_access_global", false))
		if not has_positive_benefit:
			return false
		has_city_intel_role = has_city_intel_role or int(role.get("intel_city_reveal_charges", 0)) > 0
		has_card_trace_role = has_card_trace_role or int(role.get("intel_card_trace_charges", 0)) > 0
		has_contract_trace_role = has_contract_trace_role or int(role.get("intel_contract_trace_charges", 0)) > 0
		has_remote_supply_role = has_remote_supply_role or int(role.get("card_access_extra_hops", 0)) > 0
	return names.size() == role_count and has_city_intel_role and has_card_trace_role and has_contract_trace_role and has_remote_supply_role


func _role_card_art_exposes_runtime_triggers(main: Node) -> bool:
	var bonus_card_role := main.call("_make_player_role_card", 0, 0) as Dictionary
	var resource_role := main.call("_make_player_role_card", 0, 1) as Dictionary
	var upgrade_role := main.call("_make_player_role_card", 0, 3) as Dictionary
	return String(main.call("_role_card_art_stats", bonus_card_role)).contains("公开身份") \
		and String(main.call("_role_card_art_stats", bonus_card_role)).contains("购牌:环晶电池+1") \
		and String(main.call("_role_card_art_stats", resource_role)).contains("现金流:深海菌毯+¥55/min") \
		and String(main.call("_role_card_art_stats", upgrade_role)).contains("升兽:+¥160")


func _verify_random_ai_roles_resolve_unique(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var random_index := -1
	main.set("configured_player_count", 8)
	main.set("configured_ai_player_count", 7)
	main.set("configured_role_indices", [0, random_index, random_index, random_index, random_index, random_index, random_index, random_index])
	main.call("_ensure_configured_role_indices")
	var configured := _as_array(main.get("configured_role_indices"))
	ok = ok and configured.size() >= 8 and int(configured[1]) == random_index and int(configured[7]) == random_index
	main.call("_new_game")
	var players := _as_array(main.get("players"))
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
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


func _role_index_by_name(main: Node, role_name: String) -> int:
	for role_index in range(int(main.call("_player_role_catalog_size"))):
		var role := main.call("_make_player_role_card", 0, role_index) as Dictionary
		if String(role.get("name", "")) == role_name:
			return role_index
	return -1


func _set_player_role_for_test(main: Node, player_index: int, role_name: String) -> bool:
	var role_index := _role_index_by_name(main, role_name)
	var players := _as_array(main.get("players")).duplicate(true)
	if role_index < 0 or player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	player["role_card"] = main.call("_make_player_role_card", player_index, role_index)
	players[player_index] = player
	main.set("players", players)
	return true


func _set_city_goods_for_test(main: Node, district_index: int, product_name: String, demand_name: String) -> bool:
	var districts := _as_array(main.get("districts")).duplicate(true)
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
	main.set("districts", districts)
	return true


func _set_district_goods_for_test(main: Node, district_index: int, product_name: String, demand_name: String) -> bool:
	var districts := _as_array(main.get("districts")).duplicate(true)
	if district_index < 0 or district_index >= districts.size():
		return false
	var district := districts[district_index] as Dictionary
	district["products"] = [product_name]
	district["demands"] = [demand_name]
	districts[district_index] = district
	main.set("districts", districts)
	return true


func _reset_ai_memory_for_test(main: Node, player_index: int) -> bool:
	var players := _as_array(main.get("players")).duplicate(true)
	if player_index < 0 or player_index >= players.size():
		return false
	var player := players[player_index] as Dictionary
	player["ai_memory"] = main.call("_empty_ai_memory")
	players[player_index] = player
	main.set("players", players)
	return true


func _reset_route_plan_sandbox_for_test(main: Node) -> void:
	var districts := _as_array(main.get("districts")).duplicate(true)
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
	main.set("districts", districts)
	main.set("auto_monsters", [])


func _set_product_market_focus_for_test(main: Node, focus_product: String) -> void:
	var market := (main.get("product_market") as Dictionary).duplicate(true)
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
	main.set("product_market", market)


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


func _remote_supply_test_path(main: Node) -> Dictionary:
	var districts := _as_array(main.get("districts"))
	for origin in range(districts.size()):
		var second_hop := -1
		var far_district := -1
		for candidate in range(districts.size()):
			var distance := _graph_distance_limited(districts, origin, candidate, 3)
			if distance == 2 and second_hop < 0:
				second_hop = candidate
			elif distance < 0 and far_district < 0:
				far_district = candidate
			elif distance > 2 and far_district < 0:
				far_district = candidate
		if second_hop >= 0:
			return {"origin": origin, "second_hop": second_hop, "far": far_district}
	return {}


func _verify_roguelike_depth_scaling(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var profile_i := main.call("_roguelike_planet_profile", 1) as Dictionary
	var profile_vi := main.call("_roguelike_planet_profile", 6) as Dictionary
	var ok := true
	ok = ok and int(profile_i.get("region_min", 0)) <= 6
	ok = ok and int(profile_i.get("region_max", 99)) < 10
	ok = ok and int(profile_i.get("region_min", 0)) < int(profile_vi.get("region_min", 0))
	ok = ok and int(profile_i.get("region_max", 0)) < int(profile_vi.get("region_max", 0))
	ok = ok and int(profile_vi.get("region_min", 0)) >= 40
	ok = ok and int(profile_vi.get("region_max", 0)) >= 50
	ok = ok and float(profile_i.get("width", 0.0)) < float(profile_vi.get("width", 0.0))
	ok = ok and int(profile_i.get("cash_goal", 0)) < int(profile_vi.get("cash_goal", 0))
	ok = ok and String(main.call("_roguelike_planet_profile_text", 1)).contains("区域6-9")
	ok = ok and String(main.call("_roguelike_planet_profile_text", 6)).contains("深度VI")
	ok = ok and String(main.call("_roguelike_planet_profile_text", 6)).contains("目标现金")
	main.call("_set_configured_roguelike_depth", 6)
	main.call("_generate_roguelike_districts")
	var large_districts := _as_array(main.get("districts"))
	ok = ok and large_districts.size() >= int(profile_vi.get("region_min", 0))
	ok = ok and large_districts.size() <= int(profile_vi.get("region_max", 999))
	ok = ok and float(main.get("map_width_m")) >= float(profile_vi.get("width", 0.0)) - 1.0
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


func _verify_victory_countdown_rule(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	main.set("game_over", false)
	main.set("victory_countdown_active", false)
	main.set("victory_countdown_timer", 0.0)
	main.set("victory_countdown_trigger_player", -1)
	main.set("victory_countdown_trigger_score", 0)
	var cash_goal := int(main.call("_roguelike_cash_goal"))
	var players := _as_array(main.get("players")).duplicate(true)
	if players.is_empty():
		ok = false
	else:
		var player := players[0] as Dictionary
		player["cash"] = cash_goal + 25
		players[0] = player
		main.set("players", players)
		main.call("_update_victory_countdown", 0.1)
		ok = ok and bool(main.get("victory_countdown_active"))
		ok = ok and int(main.get("victory_countdown_trigger_player")) == 0
		ok = ok and int(main.get("victory_countdown_trigger_score")) >= cash_goal
		var timer_after_start := float(main.get("victory_countdown_timer"))
		ok = ok and timer_after_start > 59.0 and timer_after_start <= 60.0
		var history := _as_array(main.get("resolved_card_history")).duplicate(true)
		history.append({
			"resolution_id": 99001,
			"queued_order": 99001,
			"player_index": 1,
			"skill": main.call("_make_skill", "城市融资1"),
			"winning_bid": 120,
			"resolved_time": float(main.get("game_time")),
		})
		main.set("resolved_card_history", history)
		var monsters := _as_array(main.get("auto_monsters")).duplicate(true)
		var actor := main.call("_make_auto_monster", monsters.size(), 0, clampi(int(main.get("selected_district")), 0, max(0, _as_array(main.get("districts")).size() - 1)), 1, 2) as Dictionary
		actor["owner_damage_cash_lost"] = 240
		actor["last_owner_damage_source"] = "烟测终局复盘"
		actor["last_owner_damage_cash_loss"] = 120
		monsters.append(actor)
		main.set("auto_monsters", monsters)
		players = _as_array(main.get("players")).duplicate(true)
		if players.size() > 1:
			var ai_player := players[1] as Dictionary
			var memory := (ai_player.get("ai_memory", {}) as Dictionary).duplicate(true)
			memory["route_plan_product"] = "环晶电池"
			memory["route_plan_stage"] = "attack_rival"
			memory["strategic_intent"] = "disrupt_competitors"
			ai_player["ai_memory"] = memory
			players[1] = ai_player
			main.set("players", players)
		var countdown_state := main.call("_capture_run_state") as Dictionary
		main.set("victory_countdown_active", false)
		main.set("victory_countdown_timer", 0.0)
		ok = ok and int(main.call("_apply_run_state", countdown_state)) == OK
		ok = ok and bool(main.get("victory_countdown_active"))
		ok = ok and float(main.get("victory_countdown_timer")) > 59.0
		main.call("_update_victory_countdown", 61.0)
		ok = ok and bool(main.get("game_over"))
		var saw_finish_log := false
		var saw_summary_log := false
		var saw_card_summary := false
		var saw_monster_summary := false
		var saw_hidden_plan_summary := false
		var saw_player_breakdown := false
		for line_variant in _as_array(main.get("log_lines")):
			var line := String(line_variant)
			if line.contains("终局倒计时结束"):
				saw_finish_log = true
			if line.contains("终局总结"):
				saw_summary_log = true
			if line.contains("关键卡牌"):
				saw_card_summary = true
			if line.contains("怪兽影响"):
				saw_monster_summary = true
			if line.contains("对手计划") and line.contains("内部决策"):
				saw_hidden_plan_summary = true
			if line.contains("玩家概览"):
				saw_player_breakdown = true
		var standings_text := String(main.call("_standings_text"))
		ok = ok and saw_finish_log and saw_summary_log and saw_card_summary and saw_monster_summary and saw_hidden_plan_summary and saw_player_breakdown
		ok = ok and standings_text.contains("终局总结") and standings_text.contains("关键卡牌") and standings_text.contains("怪兽影响") and standings_text.contains("对手计划") and standings_text.contains("内部决策") and standings_text.contains("玩家概览") and standings_text.contains("城收") and standings_text.contains("情报") and not standings_text.contains("AI路线") and not standings_text.contains("发展路线")
		var final_menu_title := main.get("menu_title_label") as Label
		var final_menu_body := main.get("menu_body_label") as Label
		var final_menu_preview := main.get("menu_preview_box") as VBoxContainer
		var final_continue_button := main.get("menu_continue_button") as Button
		ok = ok and final_menu_title != null and final_menu_title.text == "终局结算"
		ok = ok and final_menu_body != null and final_menu_body.text.contains("游戏结束") and final_menu_body.text.contains("终局总结") and final_menu_body.text.contains("接下来")
		ok = ok and final_continue_button != null and not final_continue_button.visible
		ok = ok and final_menu_preview != null and _container_button_text_contains(final_menu_preview, "查看局势排名") and _container_button_text_contains(final_menu_preview, "打开经济总览") and _container_button_text_contains(final_menu_preview, "开局准备")
		ok = ok and final_menu_preview != null and _container_label_text_contains(final_menu_preview, "终局速览") and _container_label_text_contains(final_menu_preview, "胜者") and _container_label_text_contains(final_menu_preview, "钱从哪里来") and _container_label_text_contains(final_menu_preview, "关键影响")
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


func _verify_role_passive_runtime(main: Node) -> bool:
	var players := _as_array(main.get("players"))
	var districts := _as_array(main.get("districts"))
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
	var saved_logs := _as_array(main.get("log_lines")).duplicate(true)
	var saved_callouts := _as_array(main.get("action_callouts")).duplicate(true)
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
	main.set("players", players)
	main.set("districts", districts)
	var hand_before := int(main.call("_player_counted_hand_size", players[0] as Dictionary))
	var bonus_card_granted := bool(main.call("_grant_role_bonus_card_on_purchase", 0, district_index, ""))
	var hand_after := int(main.call("_player_counted_hand_size", players[0] as Dictionary))
	players = _as_array(main.get("players")).duplicate(true)
	var resource_player := players[0] as Dictionary
	resource_player["role_card"] = main.call("_make_player_role_card", 0, 1)
	players[0] = resource_player
	main.set("players", players)
	var cash_before_resource := int((players[0] as Dictionary).get("cash", 0))
	var resource_reward := int(main.call("_apply_role_market_income_bonus", 0, district_index))
	players = _as_array(main.get("players")).duplicate(true)
	var cash_after_resource := int((players[0] as Dictionary).get("cash", 0))
	var upgrade_player := players[0] as Dictionary
	upgrade_player["role_card"] = main.call("_make_player_role_card", 0, 3)
	players[0] = upgrade_player
	main.set("players", players)
	var cash_before_upgrade := int((players[0] as Dictionary).get("cash", 0))
	var upgrade_reward := int(main.call("_apply_role_monster_upgrade_cash", 0, "测试怪兽", 1, 2, Vector2.ZERO))
	players = _as_array(main.get("players")).duplicate(true)
	var cash_after_upgrade := int((players[0] as Dictionary).get("cash", 0))
	var total_role_income := int((players[0] as Dictionary).get("total_role_income", 0))
	var passed := bonus_card_granted and hand_after == hand_before + 1
	passed = passed and resource_reward == 55 and cash_after_resource == cash_before_resource + 55
	passed = passed and upgrade_reward == 160 and cash_after_upgrade == cash_before_upgrade + 160
	passed = passed and total_role_income == 215
	players[0] = saved_player
	districts[district_index] = saved_district
	main.set("players", players)
	main.set("districts", districts)
	main.set("log_lines", saved_logs)
	main.set("action_callouts", saved_callouts)
	return passed


func _verify_role_intel_and_trace_tools(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var city_index := _first_empty_land_district_for_contract(main)
	var contract_target_index := _first_empty_land_district_for_contract(main, [city_index])
	if city_index < 0 or contract_target_index < 0:
		ok = false
	else:
		ok = ok and _set_player_role_for_test(main, 0, "星图审计庭")
		ok = ok and bool(main.call("_create_city_at_district_for_player", 1, city_index, "情报测试城市", false))
		ok = ok and bool(main.call("_create_city_at_district_for_player", 2, contract_target_index, "密约测试城市", false))
		ok = ok and bool(main.call("_use_role_city_reveal_for_player", 0, city_index, "烟测身份侦测"))
		var players_after_role := _as_array(main.get("players"))
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
			"resolved_time": float(main.get("game_time")),
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
			"resolved_time": float(main.get("game_time")),
		})
		main.set("resolved_card_history", history)
		ok = ok and int(main.call("_trace_card_owner_for_player", 0, card_resolution_id, 1, "烟测追帧")) == 1
		ok = ok and int(main.call("_trace_contract_parties_for_player", 0, contract_resolution_id, 1, "烟测密约")) == 1
		var players_after_trace := _as_array(main.get("players"))
		var known_cards := (players_after_trace[0] as Dictionary).get("known_card_owners", {}) as Dictionary
		var known_contracts := (players_after_trace[0] as Dictionary).get("known_contract_parties", {}) as Dictionary
		var known_contract := known_contracts.get(str(contract_resolution_id), {}) as Dictionary
		ok = ok and int(known_cards.get(str(card_resolution_id), -1)) == 1
		ok = ok and int(known_contract.get("proposer", -1)) == 2
		ok = ok and int(known_contract.get("target_owner", -1)) == 1
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


func _verify_ai_intel_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	if _as_array(main.get("players")).size() < 3:
		ok = false
	else:
		main.set("ai_card_decision_enabled", true)
		var source_index := _first_empty_land_district_for_contract(main)
		var target_index := _first_empty_land_district_for_contract(main, [source_index])
		if source_index < 0 or target_index < 0:
			ok = false
		else:
			var players := _as_array(main.get("players")).duplicate(true)
			for player_index in range(players.size()):
				var player := players[player_index] as Dictionary
				player["cash"] = 5000
				players[player_index] = player
			main.set("players", players)
			ok = ok and bool(main.call("_create_city_at_district_for_player", 2, source_index, "AI线索源城", false))
			ok = ok and bool(main.call("_create_city_at_district_for_player", 2, target_index, "AI推理目标城", false))
			ok = ok and _set_city_goods_for_test(main, source_index, "活体芯片", "轨迹墨水")
			ok = ok and _set_city_goods_for_test(main, target_index, "活体芯片", "轨迹墨水")
			ok = ok and bool(main.call("_mark_city_guess_for_player", 1, source_index, 2, 3, "product"))
			var city_candidates := main.call("_ai_city_guess_candidates", 1) as Array
			var city_choice := _find_city_guess_candidate(city_candidates, target_index, 2)
			ok = ok and not city_choice.is_empty()
			ok = ok and int(city_choice.get("score", 0)) >= 78
			ok = ok and bool(main.call("_ai_apply_city_guess_candidate", 1, city_choice, city_candidates))
			var players_after_city := _as_array(main.get("players"))
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
				"resolved_time": float(main.get("game_time")),
			})
			main.set("resolved_card_history", history)
			var card_candidates := main.call("_ai_card_guess_candidates", 1) as Array
			var card_choice := _find_card_guess_candidate(card_candidates, resolution_id, 2)
			ok = ok and not card_choice.is_empty()
			ok = ok and int(card_choice.get("score", 0)) >= 125
			ok = ok and bool(main.call("_ai_apply_card_guess_candidate", 1, card_choice, card_candidates))
			var traced_entry := main.call("_card_resolution_entry_by_id", resolution_id) as Dictionary
			var players_after_card := _as_array(main.get("players"))
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
	else:
		var players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 5000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "诱导电波1")]
			players[player_index] = player
		main.set("players", players)
		ok = ok and bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI诱导自城", false))
		ok = ok and bool(main.call("_create_city_at_district_for_player", 2, rival_index, "AI诱导竞品城", false))
		ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水")
		ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "轨迹墨水")
		if spare_index >= 0:
			ok = ok and bool(main.call("_create_city_at_district_for_player", 3, spare_index, "AI诱导干扰城", false))
			ok = ok and _set_city_goods_for_test(main, spare_index, "深海菌毯", "离岸水晶")
		var matching_actor := main.call("_make_auto_monster", 0, 0, own_index, 2, 2) as Dictionary
		matching_actor["resource_focus"] = ["环晶电池"]
		var decoy_actor := main.call("_make_auto_monster", 1, 1, spare_index if spare_index >= 0 else own_index, 3, 1) as Dictionary
		decoy_actor["resource_focus"] = ["深海菌毯"]
		main.set("auto_monsters", [matching_actor, decoy_actor])
		var lure_skill := main.call("_make_skill", "诱导电波1") as Dictionary
		var context := main.call("_ai_card_play_context", 1, 0, lure_skill) as Dictionary
		ok = ok and not context.is_empty()
		ok = ok and int(context.get("target_slot", -1)) == 0
		ok = ok and int(context.get("district", -1)) == rival_index
		ok = ok and int(context.get("target_city", -1)) == rival_index
		ok = ok and String(context.get("strategic_role", "")) == "monster_lure"
		ok = ok and int(context.get("resource_match", 0)) > 0
		ok = ok and int(context.get("attack_value", 0)) > 0
		var candidates := main.call("_ai_card_play_candidates", 1) as Array
		var chosen := {}
		for candidate_variant in candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "诱导电波1":
				chosen = candidate
				break
		ok = ok and not chosen.is_empty()
		var lure_queued := bool(main.call("_ai_queue_play_candidate", 1, chosen, candidates))
		ok = ok and lure_queued
		var players_after := _as_array(main.get("players"))
		ok = ok and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "target_city", rival_index)
		ok = ok and _ai_memory_has_kind_with_metadata(players_after, 1, "匿名出牌", "strategic_role", "monster_lure")
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
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
		var players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 5000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "价格套利1")]
			players[player_index] = player
		main.set("players", players)
		ok = ok and bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI焦点电池城", false))
		ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水")
		ok = ok and _set_district_goods_for_test(main, focus_index, "环晶电池", "离岸水晶")
		ok = ok and _set_district_goods_for_test(main, decoy_index, "深海菌毯", "星尘香料")
		var market := (main.get("product_market") as Dictionary).duplicate(true)
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
		main.set("product_market", market)
		var focus_product := String(main.call("_ai_refresh_economic_focus", 1, true))
		ok = ok and focus_product == "环晶电池"
		var players_after_focus := _as_array(main.get("players"))
		var memory := (players_after_focus[1] as Dictionary).get("ai_memory", {}) as Dictionary
		ok = ok and String(memory.get("economic_focus_product", "")) == "环晶电池"
		ok = ok and String(memory.get("economic_focus_reason", "")).contains("通关缺口")
		var focus_build_score := int(main.call("_auto_build_score_for_player", 1, focus_index))
		var decoy_build_score := int(main.call("_auto_build_score_for_player", 1, decoy_index))
		ok = ok and focus_build_score > decoy_build_score
		var skill := main.call("_make_skill", "价格套利1") as Dictionary
		var context := main.call("_ai_card_play_context", 1, 0, skill) as Dictionary
		ok = ok and not context.is_empty()
		ok = ok and String(context.get("product", "")) == "环晶电池"
		ok = ok and String(context.get("focus_product", "")) == "环晶电池"
		ok = ok and int(context.get("focus_bonus", 0)) > 0
		var candidates := main.call("_ai_card_play_candidates", 1) as Array
		var chosen := {}
		for candidate_variant in candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "价格套利1":
				chosen = candidate
				break
		ok = ok and not chosen.is_empty()
		ok = ok and bool(main.call("_ai_queue_play_candidate", 1, chosen, candidates))
		var players_after_queue := _as_array(main.get("players"))
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
		var players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 900
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "价格套利1")]
			players[player_index] = player
		main.set("players", players)
		var grow_created := bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI策略成长城", false))
		var grow_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水") if grow_created else false
		var grow_strategy := main.call("_ai_refresh_strategy_intent", 1, true) as Dictionary
		var grow_ok := grow_created and grow_goods and String(grow_strategy.get("intent", "")) == "grow_focus"
		ok = grow_ok and ok

	var restore_mid := int(main.call("_apply_run_state", strategy_base))
	ok = ok and restore_mid == OK
	main.set("ai_card_decision_enabled", true)
	own_index = _first_empty_land_district_for_contract(main)
	if own_index < 0:
		ok = false
	else:
		var defend_players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(defend_players.size()):
			var player := defend_players[player_index] as Dictionary
			player["cash"] = 5000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "供应链保险1")]
			defend_players[player_index] = player
		main.set("players", defend_players)
		var defend_created := bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI策略防守城", false))
		var defend_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水") if defend_created else false
		var defend_districts := _as_array(main.get("districts")).duplicate(true)
		var defend_district := defend_districts[own_index] as Dictionary
		var defend_city := defend_district.get("city", {}) as Dictionary
		defend_city["trade_route_damage"] = 4
		defend_district["city"] = defend_city
		defend_districts[own_index] = defend_district
		main.set("districts", defend_districts)
		var defend_strategy := main.call("_ai_refresh_strategy_intent", 1, true) as Dictionary
		var defend_skill := main.call("_make_skill", "供应链保险1") as Dictionary
		var defend_context := main.call("_ai_card_play_context", 1, 0, defend_skill) as Dictionary
		var defend_candidates := main.call("_ai_card_play_candidates", 1) as Array
		var defend_choice := {}
		for candidate_variant in defend_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "供应链保险1":
				defend_choice = candidate
				break
		var defend_queued := bool(main.call("_ai_queue_play_candidate", 1, defend_choice, defend_candidates)) if not defend_choice.is_empty() else false
		var players_after_defend := _as_array(main.get("players"))
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
		ok = defend_ok and ok

	restore_mid = int(main.call("_apply_run_state", strategy_base))
	ok = ok and restore_mid == OK
	main.set("ai_card_decision_enabled", true)
	own_index = _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var disrupt_players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(disrupt_players.size()):
			var player := disrupt_players[player_index] as Dictionary
			player["cash"] = 5000
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "商路黑客1")]
			disrupt_players[player_index] = player
		main.set("players", disrupt_players)
		var disrupt_own_created := bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI策略竞品自城", false))
		var disrupt_rival_created := bool(main.call("_create_city_at_district_for_player", 2, rival_index, "AI策略竞品敌城", false))
		var disrupt_own_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池") if disrupt_own_created else false
		var disrupt_rival_goods := _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料") if disrupt_rival_created else false
		var disrupt_districts := _as_array(main.get("districts")).duplicate(true)
		var rival_district := disrupt_districts[rival_index] as Dictionary
		var rival_city := rival_district.get("city", {}) as Dictionary
		rival_city["last_income"] = 820
		rival_district["city"] = rival_city
		disrupt_districts[rival_index] = rival_district
		main.set("districts", disrupt_districts)
		var disrupt_strategy := main.call("_ai_refresh_strategy_intent", 1, true) as Dictionary
		var business_candidates := main.call("_rival_business_candidates_for_player", 1) as Array
		var saw_disrupt_bonus := false
		for candidate_variant in business_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("kind", "")) == "route_sabotage" and int(candidate.get("target_city", -1)) == rival_index and String(candidate.get("strategy_intent", "")) == "disrupt_competitors" and int(candidate.get("strategy_bonus", 0)) > 0:
				saw_disrupt_bonus = true
				break
		var disrupt_skill := main.call("_make_skill", "商路黑客1") as Dictionary
		var disrupt_context := main.call("_ai_card_play_context", 1, 0, disrupt_skill) as Dictionary
		var disrupt_play_candidates := main.call("_ai_card_play_candidates", 1) as Array
		var disrupt_choice := {}
		for candidate_variant in disrupt_play_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "商路黑客1":
				disrupt_choice = candidate
				break
		var disrupt_queued := bool(main.call("_ai_queue_play_candidate", 1, disrupt_choice, disrupt_play_candidates)) if not disrupt_choice.is_empty() else false
		var players_after_disrupt := _as_array(main.get("players"))
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
		var players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 5200
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "需求改造1")]
			players[player_index] = player
		main.set("players", players)
		var seed_goods_set := _set_district_goods_for_test(main, seed_index, "环晶电池", "轨迹墨水")
		var decoy_goods_set := _set_district_goods_for_test(main, decoy_index, "深海菌毯", "星尘香料")
		var build_plan := main.call("_ai_refresh_route_plan", 1, true) as Dictionary
		var seed_build_score := int(main.call("_auto_build_score_for_player", 1, seed_index))
		var decoy_build_score := int(main.call("_auto_build_score_for_player", 1, decoy_index))
		var build_ok := seed_goods_set and decoy_goods_set and String(build_plan.get("product", "")) == "环晶电池" and String(build_plan.get("stage", "")) == "build_supply" and int(build_plan.get("partner_district", -1)) == seed_index and seed_build_score > decoy_build_score
		var route_city_created := bool(main.call("_create_city_at_district_for_player", 1, seed_index, "AI路线供给城", false))
		var route_goods_set := _set_city_goods_for_test(main, seed_index, "环晶电池", "轨迹墨水") if route_city_created else false
		var demand_plan := main.call("_ai_refresh_route_plan", 1, true) as Dictionary
		var demand_plan_ok := route_city_created and route_goods_set and String(demand_plan.get("product", "")) == "环晶电池" and String(demand_plan.get("stage", "")) == "create_demand"
		var demand_skill := main.call("_make_skill", "需求改造1") as Dictionary
		var demand_context := main.call("_ai_card_play_context", 1, 0, demand_skill) as Dictionary
		var demand_context_ok := not demand_context.is_empty() and String(demand_context.get("route_plan_product", "")) == "环晶电池" and String(demand_context.get("route_plan_stage", "")) == "create_demand" and int(demand_context.get("route_plan_bonus", 0)) > 0
		var districts_for_supply := _as_array(main.get("districts")).duplicate(true)
		var supply_district := districts_for_supply[seed_index] as Dictionary
		supply_district["card_choices"] = ["需求改造1"]
		districts_for_supply[seed_index] = supply_district
		main.set("districts", districts_for_supply)
		var actor := main.call("_make_auto_monster", 0, 0, seed_index, 1, 1) as Dictionary
		main.set("auto_monsters", [actor])
		var buy_candidates := main.call("_ai_card_buy_candidates", 1) as Array
		var saw_route_buy := false
		for candidate_variant in buy_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "需求改造1" and String(candidate.get("route_plan_stage", "")) == "create_demand" and int(candidate.get("route_plan_bonus", 0)) > 0:
				saw_route_buy = true
				break
		var demand_gap := main.call("_ai_route_gap_adjustment", 1, main.call("_make_skill", "消费刺激1"), seed_index, "环晶电池", 1) as Dictionary
		var supply_gap := main.call("_ai_route_gap_adjustment", 1, main.call("_make_skill", "生产扩张1"), seed_index, "环晶电池", 1) as Dictionary
		var route_gap_direct_ok := int(demand_gap.get("bonus", 0)) > int(supply_gap.get("bonus", 0)) and String(demand_gap.get("reason", "")).contains("补需求")
		var districts_for_gap := _as_array(main.get("districts")).duplicate(true)
		var gap_district := districts_for_gap[seed_index] as Dictionary
		gap_district["card_choices"] = ["消费刺激1", "生产扩张1"]
		districts_for_gap[seed_index] = gap_district
		main.set("districts", districts_for_gap)
		var gap_candidates := main.call("_ai_card_buy_candidates", 1) as Array
		var saw_route_gap_buy := false
		var demand_gap_score := -999999
		var supply_gap_score := -999999
		for candidate_variant in gap_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "消费刺激1":
				demand_gap_score = int(candidate.get("score", 0))
				saw_route_gap_buy = int(candidate.get("route_gap_bonus", 0)) > int(candidate.get("route_gap_penalty", 0)) and String(candidate.get("route_gap_reason", "")).contains("补需求") and int(candidate.get("route_gap_field_match", 0)) >= 2
			elif String(candidate.get("card_name", "")) == "生产扩张1":
				supply_gap_score = int(candidate.get("score", 0))
		var contract_skill := main.call("_make_skill", "环晶电池专供1") as Dictionary
		var contract_entry := {
			"skill": contract_skill,
			"contract_source_district": seed_index,
			"contract_target_district": seed_index,
			"contract_products": ["环晶电池"],
		}
		var contract_candidates := main.call("_ai_contract_response_candidates", 1, contract_entry) as Array
		var saw_route_contract := false
		for candidate_variant in contract_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("action", "")) == "签约" and String(candidate.get("route_plan_stage", "")) == "create_demand" and int(candidate.get("route_plan_bonus", 0)) > 0:
				saw_route_contract = true
				break
		var play_candidates := main.call("_ai_card_play_candidates", 1) as Array
		var play_choice := {}
		for candidate_variant in play_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "需求改造1":
				play_choice = candidate
				break
		var saw_route_gap_play := not play_choice.is_empty() and int(play_choice.get("route_gap_bonus", 0)) > int(play_choice.get("route_gap_penalty", 0)) and String(play_choice.get("route_gap_reason", "")).contains("补需求")
		var route_play_queued := bool(main.call("_ai_queue_play_candidate", 1, play_choice, play_candidates)) if not play_choice.is_empty() else false
		var players_after_queue := _as_array(main.get("players"))
		var route_play_memory := _ai_memory_has_kind_with_metadata(players_after_queue, 1, "匿名出牌", "route_plan_stage", "create_demand")
		var route_gap_score_ok := demand_gap_score > supply_gap_score
		var first_route_ok := build_ok and demand_plan_ok and demand_context_ok and saw_route_buy and route_gap_direct_ok and saw_route_gap_buy and route_gap_score_ok and saw_route_gap_play and saw_route_contract and not play_choice.is_empty() and route_play_queued and route_play_memory
		if not first_route_ok:
			print("AI route plan first-route failures: build=%s demand_plan=%s demand_context=%s route_buy=%s gap_direct=%s gap_buy=%s gap_score=%s gap_play=%s contract=%s play_choice=%s queued=%s memory=%s demand_score=%d supply_score=%d" % [
				str(build_ok),
				str(demand_plan_ok),
				str(demand_context_ok),
				str(saw_route_buy),
				str(route_gap_direct_ok),
				str(saw_route_gap_buy),
				str(route_gap_score_ok),
				str(saw_route_gap_play),
				str(saw_route_contract),
				str(not play_choice.is_empty()),
				str(route_play_queued),
				str(route_play_memory),
				demand_gap_score,
				supply_gap_score,
			])
		ok = first_route_ok and ok
		var inventory_players := _as_array(main.get("players")).duplicate(true)
		var inventory_player := inventory_players[1] as Dictionary
		var blocked_growth_a := main.call("_make_skill", "城市融资1") as Dictionary
		blocked_growth_a["play_product"] = "离岸水晶"
		blocked_growth_a["play_flow_required"] = 4
		var blocked_growth_b := main.call("_make_skill", "需求改造1") as Dictionary
		blocked_growth_b["play_product"] = "深海菌毯"
		blocked_growth_b["play_flow_required"] = 4
		inventory_player["slots"] = [blocked_growth_a, blocked_growth_b]
		inventory_player["cash"] = 5200
		inventory_player["action_cooldown"] = 0.0
		inventory_players[1] = inventory_player
		main.set("players", inventory_players)
		var inventory_districts := _as_array(main.get("districts")).duplicate(true)
		var inventory_district := inventory_districts[seed_index] as Dictionary
		inventory_district["card_choices"] = ["城市融资1", "远程补给链1"]
		inventory_districts[seed_index] = inventory_district
		main.set("districts", inventory_districts)
		var inventory_candidates := main.call("_ai_card_buy_candidates", 1) as Array
		var saw_inventory_bonus := false
		for candidate_variant in inventory_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "城市融资1" and int(candidate.get("route_hand_total", 0)) >= 2 and int(candidate.get("route_hand_blocked", 0)) >= 2 and int(candidate.get("route_inventory_bonus", 0)) > 0 and int(candidate.get("route_inventory_penalty", 0)) == 0:
				saw_inventory_bonus = true
				break
		var blocked_intel_a := main.call("_make_skill", "业主透镜1") as Dictionary
		blocked_intel_a["play_product"] = "轨迹墨水"
		blocked_intel_a["play_flow_required"] = 4
		var blocked_intel_b := main.call("_make_skill", "密约回溯1") as Dictionary
		blocked_intel_b["play_product"] = "轨迹墨水"
		blocked_intel_b["play_flow_required"] = 4
		inventory_players = _as_array(main.get("players")).duplicate(true)
		inventory_player = inventory_players[1] as Dictionary
		inventory_player["slots"] = [blocked_intel_a, blocked_intel_b]
		inventory_players[1] = inventory_player
		main.set("players", inventory_players)
		inventory_districts = _as_array(main.get("districts")).duplicate(true)
		inventory_district = inventory_districts[seed_index] as Dictionary
		inventory_district["card_choices"] = ["远程补给链1"]
		inventory_districts[seed_index] = inventory_district
		main.set("districts", inventory_districts)
		inventory_candidates = main.call("_ai_card_buy_candidates", 1) as Array
		var saw_inventory_penalty := false
		for candidate_variant in inventory_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "远程补给链1" and int(candidate.get("route_hand_blocked", 0)) >= 2 and int(candidate.get("route_inventory_penalty", 0)) > 0:
				saw_inventory_penalty = true
				break
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
		var rival_players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(rival_players.size()):
			var player := rival_players[player_index] as Dictionary
			player["cash"] = 5200
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "商路黑客1")]
			rival_players[player_index] = player
		main.set("players", rival_players)
		var attack_own_created := bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI路线自城", false))
		var attack_rival_created := bool(main.call("_create_city_at_district_for_player", 2, rival_index, "AI路线竞品城", false))
		var attack_own_goods := _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池") if attack_own_created else false
		var attack_rival_goods := _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料") if attack_rival_created else false
		var districts_for_rival := _as_array(main.get("districts")).duplicate(true)
		var rival_district := districts_for_rival[rival_index] as Dictionary
		var rival_city := rival_district.get("city", {}) as Dictionary
		rival_city["last_income"] = 920
		rival_district["city"] = rival_city
		districts_for_rival[rival_index] = rival_district
		main.set("districts", districts_for_rival)
		var attack_plan := main.call("_ai_refresh_route_plan", 1, true) as Dictionary
		var business_candidates := main.call("_rival_business_candidates_for_player", 1) as Array
		var saw_attack_business := false
		for candidate_variant in business_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("kind", "")) == "route_sabotage" and int(candidate.get("target_city", -1)) == rival_index and String(candidate.get("route_plan_stage", "")) == "attack_rival" and int(candidate.get("route_plan_bonus", 0)) > 0:
				saw_attack_business = true
				break
		var attack_skill := main.call("_make_skill", "商路黑客1") as Dictionary
		var attack_context := main.call("_ai_card_play_context", 1, 0, attack_skill) as Dictionary
		var attack_play_candidates := main.call("_ai_card_play_candidates", 1) as Array
		var attack_choice := {}
		for candidate_variant in attack_play_candidates:
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			if String(candidate.get("card_name", "")) == "商路黑客1":
				attack_choice = candidate
				break
		var attack_queued := bool(main.call("_ai_queue_play_candidate", 1, attack_choice, attack_play_candidates)) if not attack_choice.is_empty() else false
		var players_after_attack_queue := _as_array(main.get("players"))
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
	main.set("game_over", false)
	main.set("victory_countdown_active", false)
	main.set("victory_countdown_timer", 0.0)
	main.set("business_cycle_count", 0)
	main.set("auto_monsters", [])
	var players := _as_array(main.get("players")).duplicate(true)
	if players.size() < 3:
		ok = false
	else:
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 900
			player["action_cooldown"] = 0.0
			players[player_index] = player
		main.set("players", players)
		var opening := main.call("_ai_refresh_game_phase", 1, true) as Dictionary
		ok = ok and String(opening.get("phase", "")) == "opening"
		var own_index := _first_empty_land_district_for_contract(main)
		var rival_index := _first_empty_land_district_for_contract(main, [own_index])
		if own_index < 0 or rival_index < 0:
			ok = false
		else:
			ok = ok and bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI阶段自城", false))
			ok = ok and bool(main.call("_create_city_at_district_for_player", 2, rival_index, "AI阶段敌城", false))
			ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "环晶电池")
			ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料")
			var actor := main.call("_make_auto_monster", 0, 0, own_index, 1, 1) as Dictionary
			main.set("auto_monsters", [actor])
			main.set("business_cycle_count", 3)
			var midgame := main.call("_ai_refresh_game_phase", 1, true) as Dictionary
			ok = ok and String(midgame.get("phase", "")) == "midgame"
			players = _as_array(main.get("players")).duplicate(true)
			var ai_player := players[1] as Dictionary
			ai_player["cash"] = 800
			players[1] = ai_player
			var leader_player := players[2] as Dictionary
			leader_player["cash"] = int(main.call("_roguelike_cash_goal")) + 800
			players[2] = leader_player
			main.set("players", players)
			main.set("business_cycle_count", 8)
			var trailing := main.call("_ai_refresh_game_phase", 1, true) as Dictionary
			ok = ok and String(trailing.get("phase", "")) == "endgame"
			ok = ok and String(trailing.get("posture", "")) == "trailing"
			ok = ok and int(trailing.get("leader_index", -1)) == 2
			var saw_trailing_disrupt := false
			for candidate_variant in main.call("_ai_strategy_candidates", 1) as Array:
				if not (candidate_variant is Dictionary):
					continue
				var candidate := candidate_variant as Dictionary
				if String(candidate.get("intent", "")) == "disrupt_competitors" \
					and String(candidate.get("game_phase", "")) == "endgame" \
					and String(candidate.get("competitive_posture", "")) == "trailing" \
					and int(candidate.get("phase_bonus", 0)) > 0:
					saw_trailing_disrupt = true
					break
			var sabotage_bonus := int(main.call("_ai_phase_bonus_for_candidate", 1, "route_sabotage", rival_index, "环晶电池", 2, {}))
			ok = ok and saw_trailing_disrupt and sabotage_bonus > 0
			main.set("victory_countdown_active", true)
			main.set("victory_countdown_timer", 12.0)
			var countdown_urgency := int(main.call("_ai_endgame_urgency_score", 1))
			var urgent_sabotage_bonus := int(main.call("_ai_phase_bonus_for_candidate", 1, "route_sabotage", rival_index, "环晶电池", 2, {}))
			var sabotage_skill := main.call("_make_skill", "商路黑客1") as Dictionary
			var sabotage_context := main.call("_ai_card_play_context", 1, 0, sabotage_skill) as Dictionary
			ok = ok \
				and countdown_urgency > 0 \
				and urgent_sabotage_bonus > sabotage_bonus \
				and not sabotage_context.is_empty() \
				and int(sabotage_context.get("endgame_urgency", 0)) == countdown_urgency \
				and int(sabotage_context.get("phase_bonus", 0)) >= urgent_sabotage_bonus
			players = _as_array(main.get("players")).duplicate(true)
			ai_player = players[1] as Dictionary
			ai_player["cash"] = int(main.call("_roguelike_cash_goal")) + 1200
			players[1] = ai_player
			leader_player = players[2] as Dictionary
			leader_player["cash"] = 600
			players[2] = leader_player
			main.set("players", players)
			var leader_phase := main.call("_ai_refresh_game_phase", 1, true) as Dictionary
			var defense_bonus := int(main.call("_ai_phase_bonus_for_candidate", 1, "route_insurance", own_index, "环晶电池", 1, {}))
			var defense_districts := _as_array(main.get("districts")).duplicate(true)
			var defense_district := defense_districts[own_index] as Dictionary
			defense_district["damage"] = int(defense_district.get("damage", 0)) + 2
			var defense_city := defense_district.get("city", {}) as Dictionary
			defense_city["trade_route_damage"] = int(defense_city.get("trade_route_damage", 0)) + 2
			defense_city["last_income"] = maxi(600, int(defense_city.get("last_income", 0)))
			defense_district["city"] = defense_city
			defense_districts[own_index] = defense_district
			main.set("districts", defense_districts)
			var insurance_skill := main.call("_make_skill", "灾害保单1") as Dictionary
			insurance_skill["starter_play_free"] = true
			var insurance_phase_bonus := int(main.call("_ai_phase_bonus_for_candidate", 1, "city_gdp_derivative", own_index, "环晶电池", 1, insurance_skill))
			var insurance_context := main.call("_ai_card_play_context", 1, 0, insurance_skill) as Dictionary
			ok = ok and String(leader_phase.get("phase", "")) == "endgame"
			ok = ok and String(leader_phase.get("posture", "")) == "leader"
			ok = ok and defense_bonus > 0
			ok = ok \
				and insurance_phase_bonus > 0 \
				and not insurance_context.is_empty() \
				and String(insurance_context.get("policy_kind", "")) == "city_gdp_derivative_insurance" \
				and int(insurance_context.get("target_city", -1)) == own_index \
				and int(insurance_context.get("target_owner", -1)) == 1 \
				and int(insurance_context.get("generic_effect_bonus", 0)) > 0
			main.call("_record_ai_decision", 1, "阶段烟测", own_index, 123, "阶段策略记录", [], {"policy_kind": "phase_smoke", "phase_bonus": defense_bonus})
			var after_record := _as_array(main.get("players"))
			ok = ok and _ai_sample_has_field(after_record, 1, "game_phase", "endgame")
			ok = ok and _ai_sample_has_field(after_record, 1, "competitive_posture", "leader")
			ok = ok and _ai_sample_has_field(after_record, 1, "endgame_urgency")
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _drain_card_resolution_queue_for_test(main: Node, max_steps: int = 80) -> void:
	for _i in range(max_steps):
		main.call("_update_card_resolution_queue", 1.0)
		if _as_array(main.get("card_resolution_queue")).is_empty() \
			and _as_array(main.get("next_card_resolution_queue")).is_empty() \
			and (main.get("active_card_resolution") as Dictionary).is_empty():
			return


func _seed_supply_cards_near_ai_monsters_for_test(main: Node) -> void:
	var districts := _as_array(main.get("districts")).duplicate(true)
	var supply_cards := ["城市融资1", "供应链保险1", "商路黑客1", "需求改造1", "价格套利1", "交通升级1", "城市做空1"]
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
			districts[district_index] = district
	main.set("districts", districts)


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
	var players := _as_array(main.get("players"))
	for player_index in range(1, players.size()):
		for city_index_variant in _as_array(main.call("_active_city_indices_for_player", player_index)):
			_set_city_goods_for_test(main, int(city_index_variant), "环晶电池", "轨迹墨水")
	main.call("_refresh_city_networks")


func _clear_ai_cooldowns_for_test(main: Node) -> void:
	var players := _as_array(main.get("players")).duplicate(true)
	for player_index in range(1, players.size()):
		var player := players[player_index] as Dictionary
		player["action_cooldown"] = 0.0
		players[player_index] = player
	main.set("players", players)


func _verify_ai_progresses_run_smoke(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var saved_force_duration := float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous := float(main.get("card_resolution_force_simultaneous_window"))
	var ok := true
	var failures := []
	main.set("ai_card_decision_enabled", true)
	main.set("game_over", false)
	main.set("victory_countdown_active", false)
	main.set("victory_countdown_timer", 0.0)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("pending_contract_offers", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_force_duration", 0.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	var players := _as_array(main.get("players")).duplicate(true)
	if players.size() < EXPECTED_PLAYER_COUNT:
		failures.append("player count")
		ok = false
	else:
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 6200
			player["action_cooldown"] = 0.0
			players[player_index] = player
		main.set("players", players)
		var first_summon_plays := 0
		for player_index in range(1, EXPECTED_PLAYER_COUNT):
			var result := String(main.call("_ai_execute_card_turn", player_index, true))
			if result == "play":
				first_summon_plays += 1
		main.call("_auto_ai_auction_bids", true)
		_drain_card_resolution_queue_for_test(main)
		if first_summon_plays != EXPECTED_AI_PLAYER_COUNT:
			failures.append("first summons %d" % first_summon_plays)
			ok = false
		for player_index in range(1, EXPECTED_PLAYER_COUNT):
			if _ai_owned_monster_owner_count(main, player_index) <= 0:
				failures.append("missing monster owner %d" % player_index)
				ok = false
		_seed_supply_cards_near_ai_monsters_for_test(main)
		var built := int(main.call("_auto_expand_rival_syndicates", true))
		_force_ai_cities_to_shared_goods(main)
		if built < EXPECTED_AI_PLAYER_COUNT:
			failures.append("built %d" % built)
			ok = false
		for player_index in range(1, EXPECTED_PLAYER_COUNT):
			if int(main.call("_player_active_city_count", player_index)) <= 0:
				failures.append("missing city player %d" % player_index)
				ok = false
		var buy_count := 0
		var play_count := first_summon_plays
		var business_actions := 0
		var starting_cycle := int(main.get("business_cycle_count"))
		for _cycle in range(3):
			_clear_ai_cooldowns_for_test(main)
			for player_index in range(1, EXPECTED_PLAYER_COUNT):
				var result := String(main.call("_ai_execute_card_turn", player_index, true))
				if result == "buy":
					buy_count += 1
				elif result == "play":
					play_count += 1
			main.call("_auto_ai_auction_bids", true)
			_drain_card_resolution_queue_for_test(main)
			business_actions += int(main.call("_auto_rival_business_actions", true))
			main.call("_market_tick")
			main.call("_settle_city_cashflow_seconds", 60.0)
		var after_players := _as_array(main.get("players"))
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
		if play_count < EXPECTED_AI_PLAYER_COUNT:
			failures.append("play_count %d" % play_count)
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
		var leader_index := 1
		var leader_score := -999999
		for player_index in range(1, EXPECTED_PLAYER_COUNT):
			var score := int(main.call("_player_visible_settlement_estimate", player_index))
			if score > leader_score:
				leader_score = score
				leader_index = player_index
		players = _as_array(main.get("players")).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			if player_index == leader_index:
				player["cash"] = int(main.call("_roguelike_cash_goal")) + 150
			else:
				player["cash"] = 300
			players[player_index] = player
		main.set("players", players)
		main.call("_update_victory_countdown", 0.1)
		if not bool(main.get("victory_countdown_active")):
			failures.append("countdown inactive")
			ok = false
		if int(main.get("victory_countdown_trigger_player")) != leader_index:
			failures.append("countdown trigger %d expected %d" % [int(main.get("victory_countdown_trigger_player")), leader_index])
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
	main.set("ai_card_decision_enabled", true)
	main.set("game_over", false)
	main.set("victory_countdown_active", false)
	main.set("victory_countdown_timer", 0.0)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("pending_contract_offers", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_force_duration", 0.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	var players := _as_array(main.get("players")).duplicate(true)
	var districts := _as_array(main.get("districts"))
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
	main.set("players", players)
	var first_summon_plays := 0
	for player_index in range(1, max_players):
		var result := String(main.call("_ai_execute_card_turn", player_index, true))
		if result == "play":
			first_summon_plays += 1
	main.call("_auto_ai_auction_bids", true)
	_drain_card_resolution_queue_for_test(main, 160)
	if first_summon_plays != max_ai:
		failures.append("first summons %d" % first_summon_plays)
		ok = false
	for player_index in range(1, max_players):
		if _ai_owned_monster_owner_count(main, player_index) <= 0:
			failures.append("missing monster owner %d" % player_index)
			ok = false
	_seed_supply_cards_near_ai_monsters_for_test(main)
	var built := int(main.call("_auto_expand_rival_syndicates", true))
	_force_ai_cities_to_shared_goods(main)
	if built < max_ai:
		failures.append("built %d" % built)
		ok = false
	for player_index in range(1, max_players):
		if int(main.call("_player_active_city_count", player_index)) <= 0:
			failures.append("missing city %d" % player_index)
			ok = false
	var bought := {}
	var post_opening_play_count := 0
	var business_actions := 0
	for _cycle in range(4):
		_clear_ai_cooldowns_for_test(main)
		for player_index in range(1, max_players):
			var result := String(main.call("_ai_execute_card_turn", player_index, true))
			if result == "buy":
				bought[player_index] = true
			elif result == "play":
				post_opening_play_count += 1
		main.call("_auto_ai_auction_bids", true)
		_drain_card_resolution_queue_for_test(main, 160)
		business_actions += int(main.call("_auto_rival_business_actions", true))
		main.call("_market_tick")
		main.call("_settle_city_cashflow_seconds", 60.0)
	var after_players := _as_array(main.get("players"))
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
	var leader_index := 1
	var leader_score := -999999
	for player_index in range(1, max_players):
		var score := int(main.call("_player_visible_settlement_estimate", player_index))
		if score > leader_score:
			leader_score = score
			leader_index = player_index
	players = _as_array(main.get("players")).duplicate(true)
	var cash_goal := int(main.call("_roguelike_cash_goal"))
	for player_index in range(players.size()):
		var player := players[player_index] as Dictionary
		player["cash"] = cash_goal + 1200 if player_index == leader_index else 400
		players[player_index] = player
	main.set("players", players)
	main.call("_update_victory_countdown", 0.1)
	if not bool(main.get("victory_countdown_active")):
		failures.append("countdown inactive")
		ok = false
	if int(main.get("victory_countdown_trigger_player")) != leader_index:
		failures.append("countdown trigger %d expected %d" % [int(main.get("victory_countdown_trigger_player")), leader_index])
		ok = false
	var countdown_state := main.call("_capture_run_state") as Dictionary
	main.set("victory_countdown_active", false)
	main.set("victory_countdown_timer", 0.0)
	if int(main.call("_apply_run_state", countdown_state)) != OK or not bool(main.get("victory_countdown_active")):
		failures.append("countdown restore")
		ok = false
	main.call("_update_victory_countdown", 61.0)
	if not bool(main.get("game_over")):
		failures.append("not game over")
		ok = false
	var standings_text := String(main.call("_standings_text"))
	if not standings_text.contains("终局总结") or not standings_text.contains("对手计划") or not standings_text.contains("内部决策") or standings_text.contains("AI路线") or standings_text.contains("发展路线") or not standings_text.contains("关键卡牌") or not standings_text.contains("玩家概览") or not standings_text.contains("城收") or not standings_text.contains("情报"):
		failures.append("missing final summary")
		ok = false
	var final_menu_title := main.get("menu_title_label") as Label
	var final_menu_preview := main.get("menu_preview_box") as VBoxContainer
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
	var final_players := _as_array(main.get("players"))
	for player_index in range(1, max_players):
		var memory := (final_players[player_index] as Dictionary).get("ai_memory", {}) as Dictionary
		if int(memory.get("episode_learning_updates", 0)) > 0:
			finalized_ai += 1
	if finalized_ai < max_ai:
		failures.append("finalized ai %d" % finalized_ai)
		ok = false
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	if not failures.is_empty():
		print("Max AI seat smoke failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _verify_remote_supply_access(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var path := _remote_supply_test_path(main)
	if path.is_empty():
		ok = false
	else:
		var origin := int(path.get("origin", -1))
		var second_hop := int(path.get("second_hop", -1))
		var actor := main.call("_make_auto_monster", 0, 0, origin, 0, 1) as Dictionary
		main.set("auto_monsters", [actor])
		ok = ok and _set_player_role_for_test(main, 0, "星门补给商会")
		var priced_card := "垄断协议1"
		var base_price := int(main.call("_card_price", priced_card))
		main.call("_open_district_card_purchase_window", second_hop, 0)
		var remote_price := int(main.call("_card_price", priced_card, second_hop, 0))
		ok = ok and String(main.call("_district_card_access_kind", second_hop, 0)) == "extended"
		ok = ok and remote_price >= int(round(float(base_price) * 1.10))
		var monster_card := main.call("_make_skill", main.call("_monster_card_name", 0, 1)) as Dictionary
		monster_card["starter_play_free"] = false
		monster_card["summon_access"] = "monster_zone"
		ok = ok and not bool(main.call("_can_summon_monster_card_at_district", monster_card, second_hop))
		main.set("selected_player", 0)
		var players := _as_array(main.get("players"))
		ok = ok and bool(main.call("_apply_card_access_boon", players[0] as Dictionary, main.call("_make_skill", "星门采购权1")))
		var access_effect := main.call("_player_card_access_effect", 0) as Dictionary
		ok = ok and bool(access_effect.get("global", false))
		var far_district := int(path.get("far", -1))
		if far_district >= 0:
			main.call("_open_district_card_purchase_window", far_district, 0)
			var global_price := int(main.call("_card_price", priced_card, far_district, 0))
			ok = ok and String(main.call("_district_card_access_kind", far_district, 0)) == "global"
			ok = ok and global_price >= int(round(float(base_price) * 1.35))
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


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
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var forecast := main.get("weather_forecast") as Dictionary
	if forecast == null or forecast.is_empty():
		print("Missing initial weather forecast")
		ok = false
	else:
		var now := float(main.get("game_time"))
		var lead := float(forecast.get("starts_at", now)) - now
		var affected := _as_array(forecast.get("districts", []))
		ok = ok and lead >= 59.9 and lead <= 180.1
		ok = ok and affected.size() >= 1 and affected.size() <= 5
		ok = ok and String(main.call("_weather_status_text")).contains("预报")
		main.set("game_time", float(forecast.get("starts_at", now)) + 0.2)
		main.call("_update_weather_system", 0.2)
		main.call("_refresh_weather_forecast_strip")
		var active := _as_array(main.get("active_weather_zones"))
		ok = ok and not active.is_empty()
		if not active.is_empty():
			var active_entry := active[0] as Dictionary
			var active_districts := _as_array(active_entry.get("districts", []))
			ok = ok and active_districts.size() >= 1 and active_districts.size() <= 5
			var district_index := int(active_districts[0]) if not active_districts.is_empty() else -1
			if district_index >= 0:
				var production_multiplier := float(main.call("_district_weather_multiplier", district_index, "production_multiplier", 1.0))
				var transport_multiplier := float(main.call("_district_weather_multiplier", district_index, "transport_multiplier", 1.0))
				var consumption_multiplier := float(main.call("_district_weather_multiplier", district_index, "consumption_multiplier", 1.0))
				ok = ok and (absf(production_multiplier - 1.0) > 0.001 or absf(transport_multiplier - 1.0) > 0.001 or absf(consumption_multiplier - 1.0) > 0.001)
				ok = ok and String(main.call("_district_weather_summary", district_index)).contains(String(main.call("_weather_label", String(active_entry.get("type", "")))))
			ok = ok and String(main.call("_weather_status_text")).contains("影响")
			var active_label := main.get("weather_active_label") as Label
			var impact_label := main.get("weather_impact_label") as Label
			ok = ok and active_label != null and active_label.text.contains("现在：") and active_label.text.contains(String(main.call("_weather_label", String(active_entry.get("type", "")))))
			ok = ok and impact_label != null and impact_label.text.contains("产×") and impact_label.text.contains("交×") and impact_label.text.contains("消×")
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


func _verify_news_and_weather_card_rules(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var districts := _as_array(main.get("districts"))
	var district_index := -1
	for i in range(districts.size()):
		var district := districts[i] as Dictionary
		if not bool(district.get("destroyed", false)):
			district_index = i
			break
	if district_index < 0:
		return false
	main.set("selected_district", district_index)
	main.set("selected_player", 0)
	var news_skill := main.call("_make_skill", "热搜推送1") as Dictionary
	var weather_skill := main.call("_make_skill", "太阳风暴预报1") as Dictionary
	ok = ok and String(main.call("_card_codex_filter_label", "news")) == "新闻事件"
	ok = ok and String(main.call("_card_codex_filter_label", "weather")) == "天气干预"
	ok = ok and String(main.call("_card_codex_category_for_card", "热搜推送1", news_skill)) == "news"
	ok = ok and String(main.call("_card_codex_category_for_card", "太阳风暴预报1", weather_skill)) == "weather"
	ok = ok and String(main.call("_card_strategy_summary", news_skill)).contains("新闻信息战")
	ok = ok and String(main.call("_card_strategy_summary", weather_skill)).contains("天气博弈")
	ok = ok and String(main.call("_card_art_stats", weather_skill)).contains("太阳风暴")
	var before_panic := int((districts[district_index] as Dictionary).get("panic", 0))
	ok = ok and bool(main.call("_apply_news_event", news_skill))
	var after_districts := _as_array(main.get("districts"))
	var after_panic := int((after_districts[district_index] as Dictionary).get("panic", 0))
	ok = ok and after_panic > before_panic
	ok = ok and bool(main.call("_apply_weather_control", weather_skill))
	var forecast := main.get("weather_forecast") as Dictionary
	ok = ok and forecast != null and not forecast.is_empty()
	ok = ok and bool(forecast.get("forced", false))
	ok = ok and String(forecast.get("type", "")) == "solar_storm"
	ok = ok and _as_array(forecast.get("districts", [])).size() >= 1 and _as_array(forecast.get("districts", [])).size() <= 5
	ok = ok and float(forecast.get("starts_at", 0.0)) - float(main.get("game_time")) >= 59.9
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


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
	if not String(main.call("_card_art_stats", land_card)).contains("陆地怪区"):
		return false
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var previous_players := _as_array(main.get("players")).duplicate(true)
	var previous_selected_district := int(main.get("selected_district"))
	var previous_selected_player := int(main.get("selected_player"))
	var temp_actor := main.call("_make_auto_monster", previous_monsters.size(), 0, ocean_index, 0, 1) as Dictionary
	main.set("auto_monsters", [temp_actor])
	main.set("selected_player", 0)
	main.set("selected_district", ocean_index)
	var rejected := not bool(main.call("_summon_monster_from_card", players[0] as Dictionary, land_card))
	var monster_count_after := _as_array(main.get("auto_monsters")).size()
	main.set("auto_monsters", previous_monsters)
	main.set("players", previous_players)
	main.set("selected_district", previous_selected_district)
	main.set("selected_player", previous_selected_player)
	return rejected and monster_count_after == 1


func _summon_starting_monsters_for_smoke(main: Node, count: int) -> void:
	var players := _as_array(main.get("players"))
	var districts := _as_array(main.get("districts"))
	if players.is_empty() or districts.is_empty():
		return
	var landing := int(main.get("selected_district"))
	if landing < 0 or landing >= districts.size():
		landing = 0
	for i in range(min(count, players.size())):
		main.set("selected_player", i)
		main.set("selected_district", landing)
		_clear_player_cooldown(main, i)
		main.call("_use_skill", 0)
		_clear_player_cooldown(main, i)
	main.set("selected_player", 0)
	main.set("selected_district", landing)
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
	var previous_players := _as_array(main.get("players")).duplicate(true)
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
	main.set("players", players)
	main.set("auto_monsters", monsters)
	main.call("_auto_monster_take_damage", 0, 10, "烟测资金线索A", -1)
	main.call("_auto_monster_take_damage", 0, 10, "烟测资金线索B", -1)
	var after_players := _as_array(main.get("players"))
	var after_monsters := _as_array(main.get("auto_monsters"))
	var after_player := after_players[0] as Dictionary
	var after_actor := after_monsters[0] as Dictionary
	var economy_text := String(main.call("_economy_overview_text"))
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
	main.set("players", previous_players)
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
	var previous_players := _as_array(main.get("players")).duplicate(true)
	var previous_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var previous_logs := _as_array(main.get("log_lines")).duplicate(true)
	var previous_callouts := _as_array(main.get("action_callouts")).duplicate(true)
	var previous_selected_player := int(main.get("selected_player"))
	var previous_selected_district := int(main.get("selected_district"))
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
	main.set("players", players)
	main.set("auto_monsters", monsters)
	main.set("log_lines", [])
	main.set("action_callouts", [])
	main.set("selected_player", owner)
	main.set("selected_district", -1)
	var active_bound_before := _active_bound_skill_count_for_uid(players, owner, monster_uid)
	var upgrade_card := main.call("_make_skill", main.call("_monster_card_name", catalog_index, 2)) as Dictionary
	var expected_fixed_skill_count := int(upgrade_card.get("fixed_skill_count", 2))
	var expected_hp := int(upgrade_card.get("hp", 0))
	var expected_duration := float(upgrade_card.get("duration", 0.0))
	var upgraded := bool(main.call("_summon_monster_from_card", players[owner] as Dictionary, upgrade_card))
	var after_monsters := _as_array(main.get("auto_monsters"))
	var after_players := _as_array(main.get("players"))
	if after_monsters.is_empty():
		main.set("players", previous_players)
		main.set("auto_monsters", previous_monsters)
		main.set("log_lines", previous_logs)
		main.set("action_callouts", previous_callouts)
		main.set("selected_player", previous_selected_player)
		main.set("selected_district", previous_selected_district)
		return false
	var upgraded_actor := after_monsters[0] as Dictionary
	var total_after_upgrade := int(upgraded_actor.get("owner_damage_cash_total", 0))
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
		and total_after_upgrade > 1000 \
		and int(upgraded_actor.get("owner_damage_cash_lost", -1)) == 0 \
		and int(upgraded_actor.get("owner_damage_cash_pool", -1)) == total_after_upgrade \
		and int(upgraded_actor.get("last_owner_damage_cash_loss", -1)) == 0 \
		and active_bound_after >= expected_fixed_skill_count \
		and active_bound_after >= active_bound_before \
		and _callouts_contain(_as_array(main.get("action_callouts")), "升级")
	var cash_before_damage := int((after_players[owner] as Dictionary).get("cash", 0))
	var max_hp := maxi(1, int(upgraded_actor.get("max_hp", 1)))
	var expected_loss := mini(total_after_upgrade, maxi(1, int(round(float(total_after_upgrade) / float(max_hp)))))
	main.call("_auto_monster_take_damage", 0, 1, "烟测升级后受伤", -1)
	var after_damage_players := _as_array(main.get("players"))
	var after_damage_monsters := _as_array(main.get("auto_monsters"))
	var damaged_actor := after_damage_monsters[0] as Dictionary
	var damage_ok := int((after_damage_players[owner] as Dictionary).get("cash", 0)) == cash_before_damage - expected_loss \
		and bool(damaged_actor.get("owner_revealed", false)) \
		and String(damaged_actor.get("owner_clue", "")).contains("烟测升级后受伤") \
		and int(damaged_actor.get("owner_damage_cash_lost", 0)) == expected_loss \
		and int(damaged_actor.get("owner_damage_cash_pool", -1)) == total_after_upgrade - expected_loss \
		and int(damaged_actor.get("last_owner_damage_cash_loss", 0)) == expected_loss \
		and int(damaged_actor.get("last_owner_damage_amount", 0)) == 1
	main.set("players", previous_players)
	main.set("auto_monsters", previous_monsters)
	main.set("log_lines", previous_logs)
	main.set("action_callouts", previous_callouts)
	main.set("selected_player", previous_selected_player)
	main.set("selected_district", previous_selected_district)
	main.call("_refresh_ui")
	return upgrade_ok and damage_ok


func _verify_monster_takeover_resets_owner_clues(main: Node) -> bool:
	var previous_players := _as_array(main.get("players")).duplicate(true)
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
	main.set("players", players)
	main.set("auto_monsters", monsters)
	var new_owner_active_before := _active_bound_skill_count_for_uid(players, new_owner, monster_uid)
	var takeover_skill := main.call("_make_skill", "夺取怪兽1") as Dictionary
	if not bool(main.call("_apply_monster_takeover", takeover_skill, 0, new_owner)):
		main.set("players", previous_players)
		main.set("auto_monsters", previous_monsters)
		return false
	var after_takeover_players := _as_array(main.get("players"))
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
	main.call("_auto_monster_take_damage", 0, 10, "烟测夺取后受伤", -1)
	var after_damage_players := _as_array(main.get("players"))
	var after_damage_monsters := _as_array(main.get("auto_monsters"))
	var damaged_actor := after_damage_monsters[0] as Dictionary
	var after_damage_new_player := after_damage_players[new_owner] as Dictionary
	var damage_ok := int(after_damage_new_player.get("cash", 0)) == new_cash_before - 100 \
		and bool(damaged_actor.get("owner_revealed", false)) \
		and String(damaged_actor.get("owner_clue", "")).contains(String(after_damage_new_player.get("name", "玩家2"))) \
		and int(damaged_actor.get("owner_damage_cash_lost", 0)) == 100
	main.set("players", previous_players)
	main.set("auto_monsters", previous_monsters)
	return takeover_ok and damage_ok


func _verify_monster_region_card_pricing(main: Node) -> bool:
	var districts := _as_array(main.get("districts"))
	var auto_monsters := _as_array(main.get("auto_monsters"))
	if districts.is_empty() or auto_monsters.is_empty():
		return false
	var landed_index := int((auto_monsters[0] as Dictionary).get("position", -1))
	if landed_index < 0 or landed_index >= districts.size():
		return false
	var neighbors := _as_array((districts[landed_index] as Dictionary).get("neighbors", []))
	if neighbors.is_empty():
		return false
	var adjacent_index := int(neighbors[0])
	if adjacent_index < 0 or adjacent_index >= districts.size():
		return false
	var card_name := "垄断协议1"
	var base_price := int(main.call("_card_price", card_name))
	var landed_price := int(main.call("_card_price", card_name, landed_index))
	var adjacent_price := int(main.call("_card_price", card_name, adjacent_index))
	var expected_landed_price := maxi(80, int(round(float(base_price) * 0.8)))
	var pricing_ok := String(main.call("_district_card_access_kind", landed_index)) == "landed" \
		and String(main.call("_district_card_access_kind", adjacent_index)) == "adjacent" \
		and String(main.call("_district_card_access_text", landed_index)).contains("八折") \
		and String(main.call("_district_card_access_text", adjacent_index)).contains("原价") \
		and landed_price == expected_landed_price \
		and adjacent_price == base_price \
		and bool(main.call("_can_buy_card_from_district", landed_index)) \
		and bool(main.call("_can_buy_card_from_district", adjacent_index))
	for i in range(districts.size()):
		var kind := String(main.call("_district_card_access_kind", i))
		if kind == "none":
			pricing_ok = pricing_ok and not bool(main.call("_can_buy_card_from_district", i)) \
				and String(main.call("_district_card_access_text", i)).contains("不可购买")
			break
	var saved_players := _as_array(main.get("players")).duplicate(true)
	var saved_districts := districts.duplicate(true)
	var saved_monsters := auto_monsters.duplicate(true)
	var saved_selected_player := int(main.get("selected_player"))
	var saved_selected_district := int(main.get("selected_district"))
	var test_card := "城市融资1"
	var test_district := saved_districts[landed_index] as Dictionary
	test_district["card_choices"] = [test_card]
	saved_districts[landed_index] = test_district
	var test_players := saved_players.duplicate(true)
	var test_player := test_players[0] as Dictionary
	test_player["cash"] = 5000
	test_player["action_cooldown"] = 9.0
	test_player["slots"] = []
	test_players[0] = test_player
	main.set("players", test_players)
	main.set("districts", saved_districts)
	main.set("selected_player", 0)
	main.call("_select_district", landed_index)
	var disabled_monsters := saved_monsters.duplicate(true)
	for i in range(disabled_monsters.size()):
		var actor := disabled_monsters[i] as Dictionary
		actor["down"] = true
		disabled_monsters[i] = actor
	main.set("auto_monsters", disabled_monsters)
	var snapshot_buy_ok := String(main.call("_district_card_access_kind_live", landed_index)) == "none" \
		and String(main.call("_district_card_access_kind", landed_index)) == "landed" \
		and int(main.call("_card_price", test_card, landed_index, 0)) == maxi(80, int(round(float(main.call("_card_price", test_card)) * 0.8))) \
		and bool(main.call("_buy_card_for_player_from_district", 0, landed_index, test_card, false)) \
		and _player_card_names(_as_array(main.get("players")), 0).has(test_card)
	main.set("players", saved_players)
	main.set("districts", districts)
	main.set("auto_monsters", saved_monsters)
	main.set("selected_player", saved_selected_player)
	main.call("_select_district", saved_selected_district)
	pricing_ok = pricing_ok and snapshot_buy_ok
	return pricing_ok


func _verify_reacquired_card_upgrade_rules(main: Node) -> bool:
	var districts := _as_array(main.get("districts"))
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


func _private_discard_log_slice_has_secret(main: Node, start_index: int, needles: Array) -> bool:
	var logs := _as_array(main.get("log_lines"))
	for i in range(start_index, logs.size()):
		var line := String(logs[i])
		for needle_variant in needles:
			var needle := String(needle_variant)
			if needle != "" and line.contains(needle):
				return true
	return false


func _verify_private_discard_purchase_flow(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var districts := _as_array(main.get("districts"))
	if districts.is_empty():
		return false
	var district_index := -1
	for i in range(districts.size()):
		var district := districts[i] as Dictionary
		if not bool(district.get("destroyed", false)):
			district_index = i
			break
	if district_index < 0:
		return false
	var ok := true
	var prepared_districts := districts.duplicate(true)
	var district := prepared_districts[district_index] as Dictionary
	district["card_choices"] = ["城市融资1"]
	prepared_districts[district_index] = district
	main.set("districts", prepared_districts)
	main.set("auto_monsters", [main.call("_make_auto_monster", 0, 0, district_index, 0, 1)])
	main.set("selected_player", 0)
	main.set("selected_district", district_index)
	main.set("selected_market_skill", "城市融资1")
	main.set("previewed_district_card", "城市融资1")
	main.set("pending_discard_purchase", {})
	var players := _as_array(main.get("players"))
	var player := players[0] as Dictionary
	player["is_ai"] = false
	player["seat_type"] = "human"
	player["role_card"] = {}
	player["cash"] = 5000
	player["action_cooldown"] = 0.0
	player["slots"] = [
		main.call("_make_skill", "移动1"),
		main.call("_make_skill", "装甲再生1"),
		main.call("_make_skill", "舆论操控1"),
		main.call("_make_skill", "业主透镜1"),
		main.call("_make_skill", "区域供需合约1"),
	]
	player["economic_ledger"] = []
	players[0] = player
	main.set("players", players)
	var log_start := _as_array(main.get("log_lines")).size()
	ok = ok and not bool(main.call("_buy_card_for_player_from_district", 0, district_index, "城市融资1", false, true))
	var pending := main.get("pending_discard_purchase") as Dictionary
	ok = ok and not pending.is_empty() and String(pending.get("skill_name", "")) == "城市融资1"
	main.call("_refresh_ui")
	var player_box := main.get("player_box") as VBoxContainer
	ok = ok and player_box != null \
		and _container_label_text_contains(player_box, "私密弃牌确认") \
		and _container_button_text_contains(player_box, "弃掉")
	main.call("_confirm_discard_purchase", 0)
	var players_after := _as_array(main.get("players"))
	var names_after := _player_card_names(players_after, 0)
	ok = ok and (main.get("pending_discard_purchase") as Dictionary).is_empty()
	ok = ok and int(main.call("_player_counted_hand_size", players_after[0] as Dictionary)) == 5
	ok = ok and names_after.has("城市融资1") and not names_after.has("移动1")
	ok = ok and _player_ledger_contains(players_after, 0, "弃牌换购")
	ok = ok and not _private_discard_log_slice_has_secret(main, log_start, ["城市融资", "移动", "弃掉"])

	players = _as_array(main.get("players"))
	player = players[0] as Dictionary
	player["cash"] = 5000
	player["action_cooldown"] = 0.0
	player["slots"] = [
		main.call("_make_skill", "城市融资1"),
		main.call("_make_skill", "装甲再生1"),
		main.call("_make_skill", "舆论操控1"),
		main.call("_make_skill", "业主透镜1"),
		main.call("_make_skill", "区域供需合约1"),
	]
	player["economic_ledger"] = []
	players[0] = player
	main.set("players", players)
	main.set("pending_discard_purchase", {})
	var upgrade_log_start := _as_array(main.get("log_lines")).size()
	ok = ok and bool(main.call("_buy_card_for_player_from_district", 0, district_index, "城市融资1", false, true))
	var upgrade_players := _as_array(main.get("players"))
	var upgrade_names := _player_card_names(upgrade_players, 0)
	ok = ok and int(main.call("_player_counted_hand_size", upgrade_players[0] as Dictionary)) == 5
	ok = ok and upgrade_names.has("城市融资2") and not upgrade_names.has("城市融资1")
	ok = ok and (main.get("pending_discard_purchase") as Dictionary).is_empty()
	ok = ok and not _private_discard_log_slice_has_secret(main, upgrade_log_start, ["弃掉"])
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


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
	score += absf(float(skill.get("gdp_bet_multiplier", 0.0))) * 80.0
	score += maxf(0.0, float(skill.get("gdp_bet_seconds", 0.0))) * 0.5
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
			if not bool(main.call("_skill_exists", ranked_name)):
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
			var budget_points := int(main.call("_card_strength_budget_points", ranked_name))
			if budget_points <= 0:
				print("Rank has empty strength budget: %s" % ranked_name)
				return false
			if previous_budget >= 0 and budget_points < previous_budget:
				print("Rank strength budget regressed for %s: %d < %d" % [ranked_name, budget_points, previous_budget])
				return false
			previous_budget = budget_points
		checked += 1
	return checked >= 40


func _verify_ten_hour_route_pack(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var failures := []
	var families := ["应急修复", "竞争封锁", "线索悬赏", "航线预报"]
	for family_variant in families:
		var family := String(family_variant)
		var base_price := int(main.call("_card_price", "%s1" % family))
		var previous_budget := -1
		for rank in range(1, 5):
			var card_name := "%s%d" % [family, rank]
			if not bool(main.call("_skill_exists", card_name)):
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
			var budget := int(main.call("_card_strength_budget_points", card_name))
			if previous_budget >= 0 and budget < previous_budget:
				failures.append("budget regression %s" % card_name)
				ok = false
			previous_budget = budget
	var run_pool := _as_array(main.call("_current_run_card_pool"))
	for family_variant in families:
		var base_name := "%s1" % String(family_variant)
		if not run_pool.has(base_name):
			failures.append("not in run pool %s" % base_name)
			ok = false
		for rank in range(2, 5):
			if run_pool.has("%s%d" % [String(family_variant), rank]):
				failures.append("non-base in run pool %s%d" % [String(family_variant), rank])
				ok = false
	var route_expectations := {
		"应急修复1": {"route": "城市成长", "pillars": ["收益", "防御", "公开门槛"]},
		"竞争封锁1": {"route": "城市压制", "pillars": ["压制", "公开门槛"]},
		"线索悬赏1": {"route": "情报推理", "pillars": ["信息", "公开门槛"]},
		"航线预报1": {"route": "天气博弈", "pillars": ["公开门槛"]},
	}
	for card_variant in route_expectations.keys():
		var card_name := String(card_variant)
		var skill := main.call("_make_skill", card_name) as Dictionary
		var expected := route_expectations[card_name] as Dictionary
		var route_label := String(main.call("_card_strategy_route_label", skill))
		if route_label != String(expected.get("route", "")):
			failures.append("route %s -> %s" % [card_name, route_label])
			ok = false
		var pillars := _as_array(main.call("_card_balance_pillars", skill))
		for pillar_variant in _as_array(expected.get("pillars", [])):
			var pillar := String(pillar_variant)
			if not pillars.has(pillar):
				failures.append("pillar %s lacks %s -> %s" % [card_name, pillar, str(pillars)])
				ok = false
	var districts := _as_array(main.get("districts"))
	var repair_district := _first_buildable_land_district(districts)
	if repair_district < 0:
		failures.append("no repair district")
		ok = false
	else:
		ok = ok and bool(main.call("_create_city_at_district_for_player", 0, repair_district, "十小时修复烟测城", false))
		ok = ok and _set_city_goods_for_test(main, repair_district, "光合凝胶", "轨迹墨水")
		main.set("selected_player", 0)
		main.set("selected_district", repair_district)
		var districts_after_city := _as_array(main.get("districts")).duplicate(true)
		var repair_entry := (districts_after_city[repair_district] as Dictionary).duplicate(true)
		var city := (repair_entry.get("city", {}) as Dictionary).duplicate(true)
		city["trade_route_damage"] = 3
		repair_entry["city"] = city
		districts_after_city[repair_district] = repair_entry
		main.set("districts", districts_after_city)
		var repaired := bool(main.call("_apply_route_insurance", _as_array(main.get("players"))[0], main.call("_make_skill", "应急修复3")))
		var repaired_city := ((_as_array(main.get("districts"))[repair_district] as Dictionary).get("city", {}) as Dictionary)
		if not repaired or int(repaired_city.get("trade_route_damage", 99)) > 0 or float(repaired_city.get("route_flow_multiplier", 1.0)) < 1.39:
			failures.append("repair resolver damage=%d flow=%.2f" % [
				int(repaired_city.get("trade_route_damage", 99)),
				float(repaired_city.get("route_flow_multiplier", 1.0)),
			])
			ok = false
	var mid_restore := int(main.call("_apply_run_state", saved))
	if mid_restore != OK:
		failures.append("mid restore")
		ok = false
	var ai_ok := true
	var ai_districts := _as_array(main.get("districts"))
	var own_index := _first_buildable_land_district(ai_districts)
	if own_index >= 0:
		ai_ok = ai_ok and bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI修复路线烟测城", false))
		ai_ok = ai_ok and _set_city_goods_for_test(main, own_index, "光合凝胶", "轨迹墨水")
	var weather_index := _first_buildable_land_district(_as_array(main.get("districts")))
	if weather_index >= 0:
		ai_ok = ai_ok and bool(main.call("_create_city_at_district_for_player", 1, weather_index, "AI航线预报烟测城", false))
		ai_ok = ai_ok and _set_city_goods_for_test(main, weather_index, "离岸水晶", "轨迹墨水")
	var rival_index := _first_buildable_land_district(_as_array(main.get("districts")))
	if rival_index >= 0:
		ai_ok = ai_ok and bool(main.call("_create_city_at_district_for_player", 2, rival_index, "AI封锁路线烟测城", false))
		ai_ok = ai_ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料")
	if ai_ok and own_index >= 0 and rival_index >= 0:
		var players := _as_array(main.get("players")).duplicate(true)
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
		main.set("players", players)
		var ai_contexts := []
		for slot_index in range(4):
			var ctx := main.call("_ai_card_play_context", 1, slot_index, (ai_player["slots"][slot_index] as Dictionary)) as Dictionary
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
	var restore_result := int(main.call("_apply_run_state", saved))
	if not failures.is_empty():
		print("Ten-hour route pack failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _verify_development_route_balance_baseline(main: Node) -> bool:
	var required_routes := ["city_growth", "contract_route", "finance_speculation", "monster_pressure", "intel_supply"]
	var audit := _as_array(main.call("_development_route_audit"))
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
		if int(entry.get("card_count", 0)) < 3:
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
		var pillar_summary := String(main.call("_development_route_pillar_summary", entry))
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
		var balance_status := String(entry.get("balance_status", ""))
		if not ["健康", "可调", "待补强"].has(balance_status):
			print("Development route has invalid balance status: %s -> %s" % [route_id, balance_status])
			return false
		if not (entry.get("balance_notes", []) is Array):
			print("Development route balance notes are not structured: %s" % route_id)
			return false
		var balance_summary := String(main.call("_development_route_balance_summary", route_id))
		if not balance_summary.contains("强度区间") or not balance_summary.contains("预算分布") or not balance_summary.contains("支点") or not balance_summary.contains("平衡") or not balance_summary.contains("检查") or not balance_summary.contains("打法") or not balance_summary.contains("反制"):
			print("Development route balance summary is incomplete: %s -> %s" % [route_id, balance_summary])
			return false
		if int(entry.get("complete_rank_ladders", 0)) <= 0:
			print("Development route has no complete I-IV ladder: %s" % route_id)
			return false
		if _as_array(entry.get("sample_cards", [])).is_empty():
			print("Development route has no sample cards: %s" % route_id)
			return false
	var preference_coverage := main.call("_ai_development_route_preference_audit") as Dictionary
	for route_variant in required_routes:
		var route_id := String(route_variant)
		if int(preference_coverage.get(route_id, 0)) <= 0:
			print("No AI personality prefers development route: %s" % route_id)
			return false
	var diversity_audit := main.call("_ai_development_route_diversity_audit") as Dictionary
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
	var diversity_summary := String(main.call("_ai_development_route_diversity_summary"))
	if not diversity_summary.contains("核心路线5/5覆盖") or not diversity_summary.contains("城市成长") or not diversity_summary.contains("金融投机") or not diversity_summary.contains("怪兽压制"):
		print("AI route diversity summary is incomplete: %s" % diversity_summary)
		return false
	if int(main.call("_ai_development_route_bonus", 1, "city_growth")) <= 0:
		print("First AI profile does not receive a positive city-growth route bonus")
		return false
	return true


func _verify_playable_card_resolution_coverage(main: Node) -> bool:
	var report := main.call("_playable_card_resolution_coverage_report") as Dictionary
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


func _verify_cards_have_no_legacy_runtime_fields(main: Node) -> bool:
	var legacy_keys := ["charge", "control"]
	for name_variant in _as_array(main.call("_card_codex_names", "all")):
		var base_name := String(name_variant)
		var family := _skill_family(base_name)
		for rank in range(1, 5):
			var ranked_name := "%s%d" % [family, rank]
			if not bool(main.call("_skill_exists", ranked_name)):
				continue
			var skill := main.call("_make_skill", ranked_name) as Dictionary
			for legacy_key in legacy_keys:
				if skill.has(String(legacy_key)):
					print("Legacy %s field on generated skill: %s" % [String(legacy_key), ranked_name])
					return false
	var clean_state := main.call("_capture_run_state") as Dictionary
	for legacy_key in legacy_keys:
		if _variant_has_dictionary_key(clean_state, String(legacy_key)):
			print("Captured run state still contains a %s key" % String(legacy_key))
			return false
	var dirty_state := clean_state.duplicate(true)
	var dirty_players := _as_array(dirty_state.get("players", [])).duplicate(true)
	if not dirty_players.is_empty():
		var dirty_player := (dirty_players[0] as Dictionary).duplicate(true)
		var dirty_slots := _as_array(dirty_player.get("slots", [])).duplicate(true)
		if dirty_slots.is_empty():
			dirty_slots.append(main.call("_make_skill", "移动1"))
		if dirty_slots[0] is Dictionary:
			var dirty_skill := (dirty_slots[0] as Dictionary).duplicate(true)
			dirty_skill["charge"] = 999
			dirty_skill["control"] = 999
			dirty_slots[0] = dirty_skill
		dirty_player["control"] = 999
		dirty_player["slots"] = dirty_slots
		dirty_players[0] = dirty_player
		dirty_state["players"] = dirty_players
	if int(main.call("_apply_run_state", dirty_state)) != OK:
		return false
	var sanitized_state := main.call("_capture_run_state") as Dictionary
	var sanitized := true
	for legacy_key in legacy_keys:
		sanitized = sanitized and not _variant_has_dictionary_key(sanitized_state, String(legacy_key))
	main.call("_apply_run_state", clean_state)
	return sanitized


func _verify_monster_duration_expiry(main: Node) -> bool:
	var before := _as_array(main.get("auto_monsters"))
	var districts := _as_array(main.get("districts"))
	if before.is_empty() or districts.is_empty():
		return false
	var landing := clampi(int(main.get("selected_district")), 0, districts.size() - 1)
	var expiring := main.call("_make_auto_monster", before.size(), 0, landing, 0, 1) as Dictionary
	var expiring_uid := int(expiring.get("uid", 0))
	expiring["down"] = true
	expiring["remaining_time"] = 0.01
	var expanded := before.duplicate(true)
	expanded.append(expiring)
	main.set("auto_monsters", expanded)
	main.call("_update_auto_monster_durations", 0.02)
	var after := _as_array(main.get("auto_monsters"))
	if after.size() != before.size():
		return false
	for actor_variant in after:
		var actor := actor_variant as Dictionary
		if int(actor.get("uid", 0)) == expiring_uid:
			return false
	return true


func _verify_monster_card_runtime_overrides(main: Node) -> bool:
	var players := _as_array(main.get("players"))
	var districts := _as_array(main.get("districts"))
	var before_count := _as_array(main.get("auto_monsters")).size()
	if players.is_empty() or districts.is_empty():
		return false
	var card := main.call("_make_skill", main.call("_monster_card_name", 0, 1)) as Dictionary
	card["starter_play_free"] = true
	card["summon_access"] = "any"
	card["hp"] = 77
	card["duration"] = 13.5
	card["move"] = 333.0
	main.set("selected_player", 0)
	main.set("selected_district", clampi(int(main.get("selected_district")), 0, districts.size() - 1))
	if not bool(main.call("_summon_monster_from_card", players[0] as Dictionary, card)):
		return false
	var after := _as_array(main.get("auto_monsters"))
	if after.size() != before_count + 1:
		return false
	var actor := after[after.size() - 1] as Dictionary
	var matches := int(actor.get("hp", 0)) == 77 \
		and int(actor.get("max_hp", 0)) == 77 \
		and is_equal_approx(float(actor.get("duration", 0.0)), 13.5) \
		and is_equal_approx(float(actor.get("remaining_time", 0.0)), 13.5) \
		and is_equal_approx(float(actor.get("move", 0.0)), 333.0)
	main.call("_remove_auto_monster", after.size() - 1, "烟测清理")
	return matches


func _verify_monster_card_play_cash_cost(main: Node) -> bool:
	var previous_players := _as_array(main.get("players")).duplicate(true)
	var monster_count := _as_array(main.get("auto_monsters")).size()
	if previous_players.is_empty() or monster_count <= 0:
		return false
	var card := main.call("_make_skill", main.call("_monster_card_name", 0, 1)) as Dictionary
	var expected_cost := monster_count * 100
	if int(main.call("_skill_play_cash_cost", card)) != expected_cost:
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
	main.set("players", players)
	main.call("_finish_played_skill", 0, slot_index, card, 0.0)
	var after_players := _as_array(main.get("players"))
	var after_player := after_players[0] as Dictionary
	var after_slots := _as_array(after_player.get("slots", []))
	var ledger := _as_array(after_player.get("economic_ledger", []))
	var ledger_ok := false
	for entry_variant in ledger:
		var entry := entry_variant as Dictionary
		if String(entry.get("kind", "")) == "卡牌支出" \
			and int(entry.get("amount", 0)) == -expected_cost \
			and String(entry.get("label", "")).contains("怪兽·尸套龙 I级"):
			ledger_ok = true
			break
	var result := int(after_player.get("cash", 0)) == 5000 - expected_cost \
		and int(after_player.get("total_card_spend", 0)) == 37 + expected_cost \
		and slot_index < after_slots.size() \
		and after_slots[slot_index] == null \
		and ledger_ok
	main.set("players", previous_players)
	return result


func _late_weight_total(weights: Array) -> int:
	var total := 0
	for i in range(weights.size()):
		if i >= 3:
			total += int(weights[i])
	return total


func _verify_ranked_monster_action_weights(main: Node, actor: Dictionary) -> bool:
	var catalog_index := int(actor.get("catalog_index", 0))
	var position := int(actor.get("position", 0))
	var owner := int(actor.get("owner", -1))
	var rank_iv_actor := main.call("_make_auto_monster", 999, catalog_index, position, owner, 4) as Dictionary
	if int(rank_iv_actor.get("rank", 0)) != 4:
		return false
	if not bool(main.call("_assert_auto_monster_rank_weights", rank_iv_actor)):
		return false
	var rank_i_weights := main.call("_catalog_ranked_action_weights_for_index", catalog_index, false, 1) as Array
	var rank_iv_weights := main.call("_catalog_ranked_action_weights_for_index", catalog_index, false, 4) as Array
	return rank_i_weights.size() == rank_iv_weights.size() \
		and _late_weight_total(rank_iv_weights) > _late_weight_total(rank_i_weights)


func _verify_anonymous_cash_card(main: Node) -> bool:
	main.set("selected_player", 0)
	var test_slot := 10
	_set_player_skill(main, 0, test_slot, "轨道融资1")
	_clear_player_cooldown(main, 0)
	var players := _as_array(main.get("players"))
	var player_name := String((players[0] as Dictionary).get("name", "玩家1"))
	var cash_before := int((players[0] as Dictionary).get("cash", 0))
	var marker := "SMOKE_ANON_CASH_START"
	main.call("_log", marker)
	main.call("_use_skill", test_slot)
	_clear_player_cooldown(main, 0)
	players = _as_array(main.get("players"))
	return int((players[0] as Dictionary).get("cash", 0)) > cash_before \
		and _log_after_marker_hides_player(main, marker, "轨道融资1", player_name) \
		and _card_callouts_hide_player(main, "轨道融资1", player_name)


func _verify_anonymous_direct_command(main: Node) -> bool:
	main.set("selected_player", 0)
	var test_slot := 11
	_set_player_skill(main, 0, test_slot, "垂直断头刀窗口1")
	_clear_player_cooldown(main, 0)
	var actors := _as_array(main.get("auto_monsters"))
	if actors.is_empty():
		return false
	var armor_before := int((actors[0] as Dictionary).get("armor", 0))
	var players := _as_array(main.get("players"))
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
		and _log_after_marker_hides_player(main, marker, "垂直断头刀窗口1", player_name) \
		and _card_callouts_hide_player(main, "垂直断头刀窗口1", player_name)


func _first_lure_target_district(main: Node, current_position: int) -> int:
	var districts := _as_array(main.get("districts"))
	for i in range(districts.size()):
		if i == current_position:
			continue
		var district := districts[i] as Dictionary
		if bool(district.get("destroyed", false)):
			continue
		return i
	return -1


func _verify_monster_lure_replaces_control_window(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
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
	var facts := main.call("_card_rule_facts", skill) as Array
	var facts_text := "｜".join(facts)
	if not facts_text.contains("诱导提前"):
		failures.append("card facts do not include lure speedup")
		ok = false
	if not String(main.call("_card_resolution_animation_catalog_text", "诱导电波1", skill)).contains("一次性诱导"):
		failures.append("animation text does not include one-shot lure")
		ok = false
	var actors := _as_array(main.get("auto_monsters"))
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
			main.set("selected_district", target_index)
			var players := _as_array(main.get("players"))
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
			var lure_callout_seen := _callouts_contain(_as_array(main.get("action_callouts")), "诱导")
			main.call("_auto_monster_movement_tick")
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
			if not lure_callout_seen and not _callouts_contain(_as_array(main.get("action_callouts")), "诱导"):
				failures.append("lure callout missing")
				ok = false
	var restore_result := int(main.call("_apply_run_state", saved))
	if not failures.is_empty():
		print("Monster lure verification failures: %s" % " / ".join(failures))
	return ok and restore_result == OK


func _map_view_uses_unified_monster_markers() -> bool:
	var source := FileAccess.get_file_as_string(MAP_VIEW_SCRIPT_PATH)
	return source.contains("auto_monster_markers") \
		and not source.contains("monster_world_position") \
		and not source.contains("rival_monster_world_position") \
		and not source.contains("_legacy_monsters_visible")


func _log_after_marker_hides_player(main: Node, marker: String, card_name: String, player_name: String) -> bool:
	var after_marker := false
	var found_card := false
	var visible_name := String(main.call("_card_display_name", card_name)) if main.has_method("_card_display_name") else ""
	for line_variant in _as_array(main.get("log_lines")):
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
	for callout_variant in _as_array(main.get("action_callouts")):
		var callout := callout_variant as Dictionary
		var text := "%s %s %s" % [callout.get("actor", ""), callout.get("action", ""), callout.get("detail", "")]
		if not text.contains(card_name) and not (visible_name != "" and text.contains(visible_name)):
			continue
		found_card = true
		if text.contains(player_name):
			return false
	return found_card


func _economy_ledgers_respect_active_view(main: Node) -> bool:
	var selected_player := int(main.get("selected_player"))
	for entry_variant in _as_array(main.call("_economy_player_cash_entries")):
		var entry := entry_variant as Dictionary
		var ledger := String(entry.get("ledger", ""))
		var line := String(main.call("_economy_player_cash_line", entry))
		if int(entry.get("player_index", -1)) == selected_player:
			if ledger == "私人账本（不公开）" or bool(entry.get("private", true)):
				return false
		else:
			if ledger != "私人账本（不公开）" or not bool(entry.get("private", false)) or not line.contains("均为私人信息"):
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
	var previous_players := _as_array(main.get("players")).duplicate(true)
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
	var after_players := _as_array(main.get("players"))
	var after_player := after_players[player_index] as Dictionary
	var after_slots := _as_array(after_player.get("slots", []))
	var result := slot_index < after_slots.size() and after_slots[slot_index] != null
	if result:
		var after_skill := after_slots[slot_index] as Dictionary
		result = String(after_skill.get("name", "")) == String(skill.get("name", "")) \
			and String(after_skill.get("kind", "")) == "monster_bound_action" \
			and bool(after_skill.get("persistent", false)) \
			and float(after_skill.get("cooldown_left", 0.0)) > 0.0
	main.set("players", previous_players)
	return result


func _callouts_contain(callouts: Array, needle: String) -> bool:
	for callout_variant in callouts:
		var callout := callout_variant as Dictionary
		if String(callout.get("actor", "")).contains(needle) or String(callout.get("action", "")).contains(needle) or String(callout.get("detail", "")).contains(needle):
			return true
	return false


func _log_contains(main: Node, needle: String) -> bool:
	for line_variant in _as_array(main.get("log_lines")):
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
	var players := _as_array(main.get("players"))
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


func _verify_ai_card_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var saved_force_duration: float = float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous: float = float(main.get("card_resolution_force_simultaneous_window"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("card_resolution_force_duration", 5.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("pending_contract_offers", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_simultaneous_timer", 0.5)
	main.set("card_resolution_auction_timer", 0.0)
	main.set("card_resolution_auction_open", false)
	var players := _as_array(main.get("players")).duplicate(true)
	for i in range(players.size()):
		var player := players[i] as Dictionary
		player["action_cooldown"] = 0.0
		players[i] = player
	main.set("players", players)
	var candidates := main.call("_ai_card_play_candidates", 1) as Array
	ok = ok and not candidates.is_empty() and _ai_candidates_have_starter_monster(candidates)
	var first_result := String(main.call("_ai_execute_card_turn", 1, true))
	var second_result := String(main.call("_ai_execute_card_turn", 2, true))
	var queue := _as_array(main.get("card_resolution_queue"))
	ok = ok and first_result == "play" and second_result == "play"
	ok = ok and queue.size() >= 2 and bool(main.get("card_resolution_auction_open"))
	ok = ok and _queue_has_ai_card_entry(queue, 1) and _queue_has_ai_card_entry(queue, 2)
	var bid_before := _queue_highest_bid(queue)
	var raised := int(main.call("_auto_ai_auction_bids", true))
	queue = _as_array(main.get("card_resolution_queue"))
	ok = ok and raised > 0 and _queue_highest_bid(queue) >= bid_before
	var players_after_cards := _as_array(main.get("players"))
	ok = ok and _ai_memory_has_training_card_sample(players_after_cards, 1)
	main.call("_settle_city_cashflow_seconds", 60.0)
	main.call("_market_tick")
	var players_after_market := _as_array(main.get("players"))
	ok = ok and _ai_memory_has_finalized_reward(players_after_market, 1)
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	return ok and restore_result == OK


func _verify_ai_online_learning_policy(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_ai_enabled := bool(main.get("ai_card_decision_enabled"))
	var ok := true
	main.set("ai_card_decision_enabled", true)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("pending_contract_offers", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var players := _as_array(main.get("players")).duplicate(true)
		for player_index in range(players.size()):
			var player := players[player_index] as Dictionary
			player["cash"] = 6400
			player["action_cooldown"] = 0.0
			if player_index == 1:
				player["slots"] = [main.call("_make_skill", "需求改造1")]
			players[player_index] = player
		main.set("players", players)
		ok = ok and bool(main.call("_create_city_at_district_for_player", 1, own_index, "AI学习自城", false))
		ok = ok and bool(main.call("_create_city_at_district_for_player", 2, rival_index, "AI学习竞品城", false))
		ok = ok and _set_city_goods_for_test(main, own_index, "环晶电池", "轨迹墨水")
		ok = ok and _set_city_goods_for_test(main, rival_index, "环晶电池", "星尘香料")
		main.call("_record_ai_decision", 1, "匿名商业", own_index, 100, "学习测试：涨价有效", [], {
			"policy_kind": "price_pump",
			"product": "环晶电池",
			"strategy_intent": "grow_focus",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "strengthen_route",
		})
		main.call("_record_ai_decision", 1, "匿名出牌", own_index, 100, "学习测试：需求改造有效", [], {
			"policy_kind": "city_demand_shift",
			"product": "环晶电池",
			"strategy_intent": "grow_focus",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "create_demand",
		})
		main.call("_record_ai_decision", 1, "匿名合约签约", own_index, 100, "学习测试：签约有效", [], {
			"policy_kind": "contract_accept",
			"product": "环晶电池",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "create_demand",
		})
		main.call("_record_ai_decision", 1, "城市业主推理", rival_index, 100, "学习测试：城市推理有效", [], {
			"policy_kind": "city_owner_guess",
		})
		main.call("_record_ai_decision", 1, "卡牌归属押注", 83001, 100, "学习测试：卡牌押注有效", [], {
			"policy_kind": "card_owner_guess",
			"product": "环晶电池",
		})
		var rewarded_players := _as_array(main.get("players")).duplicate(true)
		var rewarded_player := rewarded_players[1] as Dictionary
		rewarded_player["cash"] = int(rewarded_player.get("cash", 0)) + 900
		rewarded_players[1] = rewarded_player
		main.set("players", rewarded_players)
		main.set("business_cycle_count", int(main.get("business_cycle_count")) + 1)
		var finalized := int(main.call("_finalize_ai_decision_rewards"))
		var players_after_learning := _as_array(main.get("players"))
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
		var business_learning_bonus := int(main.call("_ai_learning_bonus", 1, "price_pump", "grow_focus", "strengthen_route", "环晶电池", "匿名商业"))
		var card_play_learning_bonus := int(main.call("_ai_learning_bonus", 1, "city_demand_shift", "grow_focus", "create_demand", "环晶电池", "匿名出牌"))
		var contract_learning_bonus := int(main.call("_ai_learning_bonus", 1, "contract_accept", "", "create_demand", "环晶电池", "匿名合约签约"))
		var strategy_learning_bonus := int(main.call("_ai_learning_bonus", 1, "", "grow_focus", "", "环晶电池", "战略选择"))
		var route_learning_bonus := int(main.call("_ai_learning_bonus", 1, "", "grow_focus", "create_demand", "环晶电池", "路线规划"))
		var city_candidate := main.call("_ai_city_guess_owner_candidate", 1, {
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
			"resolved_time": float(main.get("game_time")),
		}
		var history := _as_array(main.get("resolved_card_history")).duplicate(true)
		history.append(card_guess_entry)
		main.set("resolved_card_history", history)
		var card_candidate := main.call("_ai_card_guess_candidate_for_owner", 1, card_guess_entry, 2) as Dictionary
		var saw_card_guess_learning := String(card_candidate.get("policy_kind", "")) == "card_owner_guess" and int(card_candidate.get("learning_bonus", 0)) > 0
		var learned_state := main.call("_capture_run_state") as Dictionary
		var reset_players := _as_array(main.get("players")).duplicate(true)
		var reset_player := reset_players[1] as Dictionary
		var reset_memory := (reset_player.get("ai_memory", {}) as Dictionary).duplicate(true)
		reset_memory["learned_policy_values"] = {}
		reset_memory["learning_updates"] = 0
		reset_player["ai_memory"] = reset_memory
		reset_players[1] = reset_player
		main.set("players", reset_players)
		var restore_learned_ok := int(main.call("_apply_run_state", learned_state)) == OK
		var restored_players := _as_array(main.get("players"))
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
	main.set("game_over", false)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("pending_contract_offers", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_auction_open", false)
	var own_index := _first_empty_land_district_for_contract(main)
	var rival_index := _first_empty_land_district_for_contract(main, [own_index])
	if own_index < 0 or rival_index < 0:
		ok = false
	else:
		var cash_goal := int(main.call("_roguelike_cash_goal"))
		var players := _as_array(main.get("players")).duplicate(true)
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
				memory["episode_last_final_score"] = 0
				memory["episode_last_rank"] = -1
				memory["episode_last_cash_goal"] = 0
				memory["episode_last_result"] = ""
				player["ai_memory"] = memory
			players[player_index] = player
		if players.size() > 0:
			var human_player := players[0] as Dictionary
			human_player["cash"] = 500
			players[0] = human_player
		if players.size() > 1:
			var winning_ai := players[1] as Dictionary
			winning_ai["cash"] = cash_goal + 2200
			players[1] = winning_ai
		if players.size() > 2:
			var losing_ai := players[2] as Dictionary
			losing_ai["cash"] = 120
			players[2] = losing_ai
		main.set("players", players)
		main.call("_record_ai_decision", 1, "匿名商业", own_index, 180, "终局学习测试：成长路线赚到钱", [], {
			"policy_kind": "price_pump",
			"product": "环晶电池",
			"strategy_intent": "grow_focus",
			"route_plan_product": "环晶电池",
			"route_plan_stage": "strengthen_route",
		})
		main.call("_record_ai_decision", 2, "匿名商业", rival_index, 120, "终局学习测试：破坏路线亏钱", [], {
			"policy_kind": "route_sabotage",
			"product": "星尘香料",
			"strategy_intent": "disrupt_competitors",
			"route_plan_product": "星尘香料",
			"route_plan_stage": "attack_rival",
		})
		main.call("_finish_game", "AI终局学习测试")
		var players_after_finish := _as_array(main.get("players"))
		var win_memory := (players_after_finish[1] as Dictionary).get("ai_memory", {}) as Dictionary
		var lose_memory := (players_after_finish[2] as Dictionary).get("ai_memory", {}) as Dictionary
		var duplicate_updates := int(main.call("_finalize_ai_episode_rewards", "AI终局学习重复调用测试"))
		var win_bonus := int(main.call("_ai_learning_bonus", 1, "price_pump", "grow_focus", "strengthen_route", "环晶电池", "匿名商业"))
		var lose_bonus := int(main.call("_ai_learning_bonus", 2, "route_sabotage", "disrupt_competitors", "attack_rival", "星尘香料", "匿名商业"))
		ok = ok and bool(main.get("game_over"))
		ok = ok and int(win_memory.get("episode_learning_updates", 0)) > 0
		ok = ok and int(win_memory.get("episode_last_rank", -1)) == 0
		ok = ok and int(win_memory.get("episode_last_final_score", 0)) >= cash_goal
		ok = ok and int(win_memory.get("episode_last_cash_goal", 0)) == cash_goal
		ok = ok and _ai_memory_has_episode_sample(win_memory, "price_pump", true)
		ok = ok and _ai_memory_has_positive_learning(win_memory, "policy:price_pump")
		ok = ok and _ai_memory_has_positive_learning(win_memory, "strategy:grow_focus")
		ok = ok and win_bonus > 0
		ok = ok and int(lose_memory.get("episode_learning_updates", 0)) > 0
		ok = ok and int(lose_memory.get("episode_last_rank", -1)) > 0
		ok = ok and int(lose_memory.get("episode_last_final_score", 0)) < cash_goal
		ok = ok and _ai_memory_has_episode_sample(lose_memory, "route_sabotage", false)
		ok = ok and _ai_memory_has_negative_learning(lose_memory, "policy:route_sabotage")
		ok = ok and lose_bonus < 0
		ok = ok and duplicate_updates == 0
		var learned_state := main.call("_capture_run_state") as Dictionary
		var reset_players := _as_array(main.get("players")).duplicate(true)
		var reset_player := reset_players[1] as Dictionary
		var reset_memory := (reset_player.get("ai_memory", {}) as Dictionary).duplicate(true)
		reset_memory["learned_policy_values"] = {}
		reset_memory["episode_learning_updates"] = 0
		reset_player["ai_memory"] = reset_memory
		reset_players[1] = reset_player
		main.set("players", reset_players)
		ok = ok and int(main.call("_apply_run_state", learned_state)) == OK
		var restored_players := _as_array(main.get("players"))
		var restored_memory := (restored_players[1] as Dictionary).get("ai_memory", {}) as Dictionary
		ok = ok and _ai_memory_has_positive_learning(restored_memory, "policy:price_pump")
		ok = ok and int(restored_memory.get("episode_learning_updates", 0)) > 0
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("ai_card_decision_enabled", saved_ai_enabled)
	return ok and restore_result == OK


func _first_rival_city_index(main: Node, active_player_index: int) -> int:
	var districts := _as_array(main.get("districts"))
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
	for marker_variant in _as_array(main.call("_city_markers_for_selected_player")):
		var marker := marker_variant as Dictionary
		if String(marker.get("tag", "")) == "?":
			return true
	return false


func _city_public_clue_exists(main: Node) -> bool:
	for district_variant in _as_array(main.get("districts")):
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		if String(city.get("last_public_clue", "")) != "":
			return true
	return false


func _city_public_clue_history_exists(main: Node) -> bool:
	for district_variant in _as_array(main.get("districts")):
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


func _container_card_art_kind_contains(container: Node, kind: String) -> bool:
	for child in container.get_children():
		if child.has_method("set_card") and String(child.get("card_kind")) == kind:
			return true
		if child is Node and _container_card_art_kind_contains(child, kind):
			return true
	return false


func _container_card_art_stats_contains(container: Node, needle: String) -> bool:
	for child in container.get_children():
		if child.has_method("set_card") and String(child.get("card_stats")).contains(needle):
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


func _clear_player_cooldown(main: Node, player_index: int) -> void:
	var players := _as_array(main.get("players"))
	if player_index < 0 or player_index >= players.size():
		return
	var player := players[player_index] as Dictionary
	player["action_cooldown"] = 0.0
	players[player_index] = player
	main.set("players", players)


func _verify_card_resolution_auction_and_guess(main: Node) -> Dictionary:
	var result := {
		"five_second_window": false,
		"simultaneous_overlay_status": false,
		"simultaneous_requirement_visible": false,
		"bid_status_waiting_visible": false,
		"highest_bid_wins": false,
		"auction_overlay_status": false,
		"bid_status_auction_visible": false,
		"track_badges_auction_visible": false,
		"clockwise_tie": false,
		"batch_order_locked": false,
		"active_overlay_status": false,
		"active_overlay_badges_visible": false,
		"active_overlay_requirement_snapshot_visible": false,
		"active_overlay_my_badge_visible": false,
		"active_overlay_animation_visible": false,
		"active_overlay_stage_map_effects": false,
		"card_stage_effect_styles_visible": false,
		"bid_status_locked_visible": false,
		"track_badges_locked_visible": false,
		"track_requirement_badges_visible": false,
		"track_visual_cues_visible": false,
		"card_aftermath_clues_visible": false,
		"economy_overview_card_aftermath_visible": false,
		"tip_payment_clues_visible": false,
		"locked_bids_pay_in_sequence": false,
		"one_shot_leaves_hand_on_queue": false,
		"accepts_mid_batch_cards": false,
		"next_batch_track_visible": false,
		"next_batch_save_state": false,
		"next_batch_single_auction": false,
		"cross_batch_tip_payment": false,
		"track_records_history": false,
		"track_supports_horizontal_drag_scroll": false,
		"correct_guess": false,
		"correct_guess_badge_visible": false,
		"inference_board_public_card_owner_visible": false,
		"inference_board_card_requirement_visible": false,
		"wrong_guess": false,
		"wrong_guess_status_visible": false,
		"public_logs_anonymous": false,
	}
	var saved_players: Array = _as_array(main.get("players")).duplicate(true)
	var saved_districts: Array = _as_array(main.get("districts")).duplicate(true)
	var saved_movement_trails: Array = _as_array(main.get("movement_trails")).duplicate(true)
	var saved_action_callouts: Array = _as_array(main.get("action_callouts")).duplicate(true)
	var saved_map_effects: Array = _as_array(main.get("map_event_effects")).duplicate(true)
	var saved_queue: Array = _as_array(main.get("card_resolution_queue")).duplicate(true)
	var saved_next_queue: Array = _as_array(main.get("next_card_resolution_queue")).duplicate(true)
	var saved_active: Dictionary = (main.get("active_card_resolution") as Dictionary).duplicate(true)
	var saved_history: Array = _as_array(main.get("resolved_card_history")).duplicate(true)
	var saved_logs: Array = _as_array(main.get("log_lines")).duplicate(true)
	var saved_timer: float = float(main.get("card_resolution_timer"))
	var saved_simultaneous_timer: float = float(main.get("card_resolution_simultaneous_timer"))
	var saved_auction_timer: float = float(main.get("card_resolution_auction_timer"))
	var saved_force_duration: float = float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous: float = float(main.get("card_resolution_force_simultaneous_window"))
	var saved_auction_open: bool = bool(main.get("card_resolution_auction_open"))
	var saved_batch_locked: bool = bool(main.get("card_resolution_batch_locked"))
	var saved_batch_reference: int = int(main.get("card_resolution_batch_reference_player"))
	var saved_sequence: int = int(main.get("card_resolution_sequence"))
	var saved_last_player: int = int(main.get("last_card_resolution_player_index"))
	var saved_visual_id: int = int(main.get("card_resolution_visual_id"))
	var saved_visual_stage: int = int(main.get("card_resolution_visual_stage"))
	var saved_selected_player: int = int(main.get("selected_player"))
	var saved_selected_district: int = int(main.get("selected_district"))
	var saved_track_id: int = int(main.get("selected_card_resolution_id"))

	var test_players: Array = saved_players.duplicate(true)
	if test_players.size() < 4:
		return result
	for i in range(4):
		var player: Dictionary = test_players[i]
		player["cash"] = 5000
		player["action_cooldown"] = 0.0
		player["queued_card_tip"] = 0
		test_players[i] = player
	main.set("players", test_players)
	main.set("movement_trails", [])
	main.set("action_callouts", [])
	main.set("map_event_effects", [])
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("active_card_resolution", {})
	main.set("resolved_card_history", [])
	main.set("card_resolution_timer", 0.0)
	main.set("card_resolution_simultaneous_timer", 0.0)
	main.set("card_resolution_auction_timer", 0.0)
	main.set("card_resolution_force_duration", 5.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_batch_reference_player", -1)
	main.set("card_resolution_sequence", 0)
	main.set("last_card_resolution_player_index", -1)
	main.set("card_resolution_visual_id", -1)
	main.set("card_resolution_visual_stage", -1)
	for i in range(4):
		_set_player_skill(main, i, 20 + i, "舆论操控1")

	main.set("selected_player", 0)
	var first_queued: bool = bool(main.call("_queue_skill_resolution", 0, 20, -1))
	var players_after_first_queue: Array = _as_array(main.get("players"))
	var first_queue_slots: Array = _as_array((players_after_first_queue[0] as Dictionary).get("slots", []))
	result["one_shot_leaves_hand_on_queue"] = first_queue_slots.size() > 20 and first_queue_slots[20] == null
	var first_active: Dictionary = main.get("active_card_resolution") as Dictionary
	var simultaneous_window_started: bool = first_queued \
		and first_active.is_empty() \
		and is_equal_approx(float(main.get("card_resolution_simultaneous_timer")), 0.5) \
		and not bool(main.get("card_resolution_auction_open"))
	var status_label := main.get("card_resolution_status_label") as Label
	var simultaneous_status := String(status_label.text) if status_label != null else ""
	result["simultaneous_overlay_status"] = simultaneous_window_started \
		and simultaneous_status.contains("阶段：同时判定") \
		and simultaneous_status.contains("新牌：0.5秒内可加入") \
		and simultaneous_status.contains("可加价：预设")
	var overlay_body_label := main.get("card_resolution_body_label") as Label
	var simultaneous_body := String(overlay_body_label.text) if overlay_body_label != null else ""
	result["simultaneous_requirement_visible"] = simultaneous_window_started \
		and simultaneous_body.contains("队首公开条件") \
		and simultaneous_body.contains("起始怪兽牌")
	main.call("_refresh_ui")
	var player_box := main.get("player_box") as VBoxContainer
	result["bid_status_waiting_visible"] = simultaneous_window_started \
		and player_box != null \
		and _container_label_text_contains(player_box, "报价状态：候补牌待竞价") \
		and _container_label_text_contains(player_box, "等待0.5秒同时判定")
	var auction_log_start: int = _as_array(main.get("log_lines")).size()
	var bids := [100, 200, 200]
	for i in range(1, 4):
		main.set("selected_player", i)
		main.call("_set_selected_card_tip", int(bids[i - 1]))
		main.call("_queue_skill_resolution", i, 20 + i, -1)
	var auction_status := String(status_label.text) if status_label != null else ""
	result["five_second_window"] = simultaneous_window_started \
		and (main.get("active_card_resolution") as Dictionary).is_empty() \
		and bool(main.get("card_resolution_auction_open")) \
		and is_equal_approx(float(main.get("card_resolution_auction_timer")), 5.0)
	result["auction_overlay_status"] = bool(result["five_second_window"]) \
		and auction_status.contains("阶段：匿名竞价") \
		and auction_status.contains("最高公开报价¥200") \
		and auction_status.contains("可加价：是")
	main.call("_refresh_ui")
	player_box = main.get("player_box") as VBoxContainer
	result["bid_status_auction_visible"] = bool(result["five_second_window"]) \
		and player_box != null \
		and _container_label_text_contains(player_box, "报价状态：候补牌参拍中") \
		and _container_label_text_contains(player_box, "可继续加价")
	var auction_track := main.get("card_resolution_track") as HBoxContainer
	result["track_badges_auction_visible"] = bool(result["five_second_window"]) \
		and auction_track != null \
		and _container_label_text_contains(auction_track, "我的候补匿名牌") \
		and _container_label_text_contains(auction_track, "最高公开报价") \
		and _container_label_text_contains(auction_track, "当前竞价队首") \
		and not _container_label_text_contains(auction_track, "公开归属标签｜玩家")

	main.call("_update_card_resolution_queue", 5.1)
	var active_after_auction: Dictionary = main.get("active_card_resolution") as Dictionary
	var locked_queue: Array = _as_array(main.get("card_resolution_queue"))
	var active_status := String(status_label.text) if status_label != null else ""
	result["highest_bid_wins"] = int(active_after_auction.get("player_index", -1)) == 2
	result["active_overlay_status"] = not active_after_auction.is_empty() \
		and active_status.contains("阶段：公开展示") \
		and active_status.contains("锁定候补") \
		and active_status.contains("可加价：否") \
		and active_status.contains("新牌：进入下一批等待")
	var overlay := main.get("card_resolution_overlay") as Control
	result["active_overlay_badges_visible"] = not active_after_auction.is_empty() \
		and overlay != null \
		and _container_label_text_contains(overlay, "归属未知") \
		and _container_label_text_contains(overlay, "成交小费¥200") \
		and _container_label_text_contains(overlay, "锁定候补3") \
		and not _container_label_text_contains(overlay, "公开归属标签｜玩家")
	result["active_overlay_requirement_snapshot_visible"] = not active_after_auction.is_empty() \
		and overlay != null \
		and _container_label_text_contains(overlay, "出牌条件｜") \
		and _container_label_text_contains(overlay, "起始怪兽牌")
	result["active_overlay_animation_visible"] = not active_after_auction.is_empty() \
		and overlay != null \
		and _container_label_text_contains(overlay, "结算演出") \
		and _container_label_text_contains(overlay, "当前分镜：开场") \
		and _container_label_text_contains(overlay, "视觉提示") \
		and _container_label_text_contains(overlay, "地图播报") \
		and _container_label_text_contains(overlay, "展示进度") \
		and _container_label_text_contains(overlay, "落点：")
	if not active_after_auction.is_empty():
		main.call("_show_card_resolution_overlay", active_after_auction, 2.4)
		main.call("_show_card_resolution_overlay", active_after_auction, 0.4)
	result["active_overlay_stage_map_effects"] = not active_after_auction.is_empty() \
		and _map_effects_contain(main, "card_open") \
		and _map_effects_contain(main, "card_resolve") \
		and _map_effects_contain(main, "card_afterglow") \
		and _as_array(main.get("movement_trails")).size() >= 1
	main.set("map_event_effects", [])
	var style_entry := {"selected_district": int(main.get("selected_district")), "target_slot": -1}
	var city_style_skill := main.call("_make_skill", "城市融资1") as Dictionary
	var product_style_skill := main.call("_make_skill", "价格套利1") as Dictionary
	var monster_style_name := String(main.call("_monster_card_name", 0, 1))
	var monster_style_skill := main.call("_make_skill", monster_style_name) as Dictionary
	main.call("_emit_card_resolution_stage_visual", style_entry, city_style_skill, 1)
	main.call("_emit_card_resolution_stage_visual", style_entry, product_style_skill, 1)
	main.call("_emit_card_resolution_stage_visual", style_entry, monster_style_skill, 0)
	result["card_stage_effect_styles_visible"] = _map_effects_contain_style(main, "card_resolve", "city") \
		and _map_effects_contain_style(main, "card_resolve", "product") \
		and _map_effects_contain_style(main, "card_open", "summon")
	var owner_for_overlay := int(active_after_auction.get("player_index", -1))
	if owner_for_overlay >= 0:
		main.set("selected_player", owner_for_overlay)
		main.call("_show_card_resolution_overlay", active_after_auction, float(main.get("card_resolution_timer")))
		result["active_overlay_my_badge_visible"] = overlay != null \
			and _container_label_text_contains(overlay, "我的展示中匿名牌")
	main.set("selected_player", 3)
	main.call("_show_card_resolution_overlay", active_after_auction, float(main.get("card_resolution_timer")))
	main.call("_refresh_ui")
	player_box = main.get("player_box") as VBoxContainer
	result["bid_status_locked_visible"] = not active_after_auction.is_empty() \
		and player_box != null \
		and _container_label_text_contains(player_box, "报价状态：候补牌已锁定") \
		and _container_label_text_contains(player_box, "不能加价：批次已封盘/展示中")
	var locked_track := main.get("card_resolution_track") as HBoxContainer
	result["track_badges_locked_visible"] = not active_after_auction.is_empty() \
		and locked_track != null \
		and _container_label_text_contains(locked_track, "正在全屏展示") \
		and _container_label_text_contains(locked_track, "下一张将展示") \
		and _container_label_text_contains(locked_track, "我的候补匿名牌")
	result["track_requirement_badges_visible"] = not active_after_auction.is_empty() \
		and locked_track != null \
		and _container_label_text_contains(locked_track, "出牌条件｜") \
		and _container_label_text_contains(locked_track, "起始怪兽牌")
	result["track_visual_cues_visible"] = not active_after_auction.is_empty() \
		and locked_track != null \
		and _container_label_text_contains(locked_track, "演出风格｜") \
		and _container_label_text_contains(locked_track, "地图播报｜")
	result["clockwise_tie"] = locked_queue.size() >= 1 and int((locked_queue[0] as Dictionary).get("player_index", -1)) == 3
	result["batch_order_locked"] = bool(main.get("card_resolution_batch_locked")) \
		and not bool(main.get("card_resolution_auction_open")) \
		and locked_queue.size() == 3 \
		and int((locked_queue[0] as Dictionary).get("tip", -1)) == 200 \
		and int((locked_queue[1] as Dictionary).get("tip", -1)) == 100 \
		and int((locked_queue[2] as Dictionary).get("tip", -1)) == 0

	main.set("selected_player", 3)
	var locked_bid_before: int = int((locked_queue[0] as Dictionary).get("tip", -1))
	main.call("_set_selected_card_tip", 500)
	var locked_queue_after_bid: Array = _as_array(main.get("card_resolution_queue"))
	result["batch_order_locked"] = bool(result["batch_order_locked"]) \
		and int((locked_queue_after_bid[0] as Dictionary).get("tip", -1)) == locked_bid_before
	_set_player_skill(main, 0, 30, "舆论操控1")
	_set_player_skill(main, 1, 30, "舆论操控1")
	var first_accepted_during_batch: bool = bool(main.call("_queue_skill_resolution", 0, 30, -1))
	var second_accepted_during_batch: bool = bool(main.call("_queue_skill_resolution", 1, 30, -1))
	var waiting_next_batch: Array = _as_array(main.get("next_card_resolution_queue"))
	result["accepts_mid_batch_cards"] = first_accepted_during_batch \
		and second_accepted_during_batch \
		and _as_array(main.get("card_resolution_queue")).size() == 3 \
		and waiting_next_batch.size() == 2 \
		and not bool(main.get("card_resolution_auction_open"))
	main.call("_refresh_ui")
	var waiting_track := main.get("card_resolution_track") as HBoxContainer
	result["next_batch_track_visible"] = waiting_track != null \
		and _container_button_text_contains(waiting_track, "下批等待1") \
		and _container_label_text_contains(waiting_track, "下一批等待区")
	var waiting_save_state := main.call("_capture_run_state") as Dictionary
	result["next_batch_save_state"] = _as_array(waiting_save_state.get("next_card_resolution_queue", [])).size() == 2

	main.call("_update_card_resolution_queue", 5.1)
	main.call("_update_card_resolution_queue", 5.1)
	main.call("_update_card_resolution_queue", 5.1)
	main.call("_update_card_resolution_queue", 5.1)
	var cash_after_batch: Array = _as_array(main.get("players"))
	result["locked_bids_pay_in_sequence"] = int((cash_after_batch[0] as Dictionary).get("cash", 0)) == 5000 \
		and int((cash_after_batch[1] as Dictionary).get("cash", 0)) == 4900 \
		and int((cash_after_batch[2] as Dictionary).get("cash", 0)) == 5200 \
		and int((cash_after_batch[3] as Dictionary).get("cash", 0)) == 4900
	var promoted_queue: Array = _as_array(main.get("card_resolution_queue"))
	result["next_batch_single_auction"] = (main.get("active_card_resolution") as Dictionary).is_empty() \
		and waiting_next_batch.size() == 2 \
		and _as_array(main.get("next_card_resolution_queue")).is_empty() \
		and promoted_queue.size() == 2 \
		and bool(main.get("card_resolution_auction_open")) \
		and is_equal_approx(float(main.get("card_resolution_auction_timer")), 5.0) \
		and int(main.get("card_resolution_batch_reference_player")) == 0 \
		and int(main.get("last_card_resolution_player_index")) == 0
	main.set("selected_player", 1)
	main.call("_set_selected_card_tip", 100)
	main.call("_update_card_resolution_queue", 5.1)
	var cross_batch_active := main.get("active_card_resolution") as Dictionary
	var cross_batch_players := _as_array(main.get("players"))
	result["cross_batch_tip_payment"] = int(cross_batch_active.get("player_index", -1)) == 1 \
		and bool(cross_batch_active.get("tip_paid", false)) \
		and int(cross_batch_active.get("tip_paid_amount", 0)) == 100 \
		and int((cross_batch_players[0] as Dictionary).get("cash", 0)) == 5100 \
		and int((cross_batch_players[1] as Dictionary).get("cash", 0)) == 4800

	var history: Array = _as_array(main.get("resolved_card_history"))
	main.call("_refresh_ui")
	var track := main.get("card_resolution_track") as HBoxContainer
	result["track_records_history"] = history.size() == 4 and track != null and track.get_child_count() >= 5
	result["card_aftermath_clues_visible"] = history.size() >= 1 \
		and String((history[0] as Dictionary).get("aftermath_clue", "")) != "" \
		and track != null \
		and _container_label_text_contains(track, "余波线索｜") \
		and _callouts_contain(_as_array(main.get("action_callouts")), "卡牌余波") \
		and _map_effects_contain_min_duration(main, "card_afterglow", 7.5)
	var economy_aftermath_text := String(main.call("_economy_overview_text"))
	var first_aftermath_clue := String((history[0] as Dictionary).get("aftermath_clue", "")) if history.size() >= 1 else ""
	result["economy_overview_card_aftermath_visible"] = bool(result["card_aftermath_clues_visible"]) \
		and economy_aftermath_text.contains("最近卡牌余波") \
		and economy_aftermath_text.contains("线索:") \
		and economy_aftermath_text.contains(first_aftermath_clue) \
		and economy_aftermath_text.contains("归属未知")
	var second_tip_clue := String(main.call("_card_resolution_tip_clue_text", history[1] as Dictionary)) if history.size() >= 2 else ""
	result["tip_payment_clues_visible"] = history.size() >= 2 \
		and second_tip_clue.contains("已私密支付") \
		and second_tip_clue.contains("轨道#") \
		and second_tip_clue.contains("身份仍匿名") \
		and track != null \
		and _container_label_text_contains(track, "竞价线索｜") \
		and economy_aftermath_text.contains("竞价:") \
		and economy_aftermath_text.contains("已私密支付") \
		and economy_aftermath_text.contains("身份仍匿名")
	var track_scroll := main.get("card_resolution_track_scroll") as ScrollContainer
	if not history.is_empty():
		var overflow_history := history.duplicate(true)
		for i in range(10):
			var overflow_entry: Dictionary = (history[i % history.size()] as Dictionary).duplicate(true)
			overflow_entry["resolution_id"] = 900000 + i
			overflow_entry["queued_order"] = 900000 + i
			overflow_history.append(overflow_entry)
		main.set("resolved_card_history", overflow_history)
		main.call("_refresh_ui")
		await process_frame
	main.call("_set_card_resolution_track_scroll", 0)
	var max_track_scroll: int = int(main.call("_card_resolution_track_max_scroll"))
	var scrolled_track_position: int = int(main.call("_scroll_card_resolution_track_by", 160))
	result["track_supports_horizontal_drag_scroll"] = bool(result["track_records_history"]) \
		and track_scroll != null \
		and max_track_scroll > 0 \
		and scrolled_track_position > 0 \
		and int(track_scroll.scroll_horizontal) == scrolled_track_position
	main.set("resolved_card_history", history)
	main.call("_refresh_ui")
	if history.size() >= 2:
		var first_history: Dictionary = history[0]
		var second_history: Dictionary = history[1]
		var first_id: int = int(first_history.get("resolution_id", -1))
		var second_id: int = int(second_history.get("resolution_id", -1))
		main.set("selected_player", 1)
		var owner_cash_before: int = int((_as_array(main.get("players"))[2] as Dictionary).get("cash", 0))
		var guesser_cash_before: int = int((_as_array(main.get("players"))[1] as Dictionary).get("cash", 0))
		main.call("_guess_card_resolution_owner", first_id, 2)
		var after_correct_players: Array = _as_array(main.get("players"))
		var revealed_first: Dictionary = main.call("_card_resolution_entry_by_id", first_id) as Dictionary
		result["correct_guess"] = bool(revealed_first.get("public_owner_revealed", false)) \
			and String(revealed_first.get("public_owner_label", "")).contains("玩家3") \
			and int((after_correct_players[2] as Dictionary).get("cash", 0)) == owner_cash_before - 100 \
			and int((after_correct_players[1] as Dictionary).get("cash", 0)) == guesser_cash_before + 100
		main.set("selected_card_resolution_id", first_id)
		main.call("_refresh_ui")
		track = main.get("card_resolution_track") as HBoxContainer
		result["correct_guess_badge_visible"] = track != null \
			and _container_label_text_contains(track, "公开归属标签") \
			and _container_label_text_contains(track, "玩家3")
		var inference_after_correct := String(main.call("_economy_overview_text"))
		result["inference_board_public_card_owner_visible"] = bool(result["correct_guess"]) \
			and inference_after_correct.contains("当前玩家推理板") \
			and inference_after_correct.contains("公开卡牌归属｜玩家3×1") \
			and inference_after_correct.contains("只统计已经贴公开归属标签")
		var requirement_history := _as_array(main.get("resolved_card_history")).duplicate(true)
		var requirement_entry: Dictionary = first_history.duplicate(true)
		var requirement_skill := main.call("_make_skill", "夺取怪兽1") as Dictionary
		requirement_entry["skill"] = requirement_skill
		requirement_entry["public_owner_revealed"] = false
		requirement_entry["play_requirement_product"] = "活体芯片"
		requirement_entry["play_requirement_flow"] = 2
		requirement_entry["play_cash_cost"] = 0
		requirement_history.append(requirement_entry)
		main.set("resolved_card_history", requirement_history)
		var inference_with_requirement := String(main.call("_economy_overview_text"))
		result["inference_board_card_requirement_visible"] = inference_with_requirement.contains("卡牌条件反推") \
			and inference_with_requirement.contains("活体芯片流动≥2") \
			and (inference_with_requirement.contains("我方满足") or inference_with_requirement.contains("我方不足")) \
			and inference_with_requirement.contains("归属未知") \
			and inference_with_requirement.contains("只对照我方当前流动")
		main.set("resolved_card_history", history)
		var wrong_guesser_before: int = int((after_correct_players[1] as Dictionary).get("cash", 0))
		var wrong_owner_before: int = int((after_correct_players[3] as Dictionary).get("cash", 0))
		main.call("_guess_card_resolution_owner", second_id, 0)
		var after_wrong_players: Array = _as_array(main.get("players"))
		var unrevealed_second: Dictionary = main.call("_card_resolution_entry_by_id", second_id) as Dictionary
		result["wrong_guess"] = not bool(unrevealed_second.get("public_owner_revealed", false)) \
			and (_as_array(unrevealed_second.get("guessers", []))).has(1) \
			and int((after_wrong_players[1] as Dictionary).get("cash", 0)) == wrong_guesser_before - 100 \
			and int((after_wrong_players[3] as Dictionary).get("cash", 0)) == wrong_owner_before + 100
		main.set("selected_card_resolution_id", second_id)
		main.call("_refresh_ui")
		track = main.get("card_resolution_track") as HBoxContainer
		result["wrong_guess_status_visible"] = track != null \
			and _container_label_text_contains(track, "我的竞猜：已押注") \
			and _container_label_text_contains(track, "真实归属仍隐藏") \
			and not _container_label_text_contains(track, "公开归属标签｜玩家4")

	var public_lines: Array = _as_array(main.get("log_lines"))
	var public_text := ""
	for i in range(auction_log_start, public_lines.size()):
		public_text += String(public_lines[i]) + "\n"
	result["public_logs_anonymous"] = public_text.contains("公开报价") \
		and not public_text.contains("玩家2将") \
		and not public_text.contains("玩家3将") \
		and not public_text.contains("玩家4将")

	main.set("players", saved_players)
	main.set("districts", saved_districts)
	main.set("movement_trails", saved_movement_trails)
	main.set("action_callouts", saved_action_callouts)
	main.set("map_event_effects", saved_map_effects)
	main.set("card_resolution_queue", saved_queue)
	main.set("next_card_resolution_queue", saved_next_queue)
	main.set("active_card_resolution", saved_active)
	main.set("resolved_card_history", saved_history)
	main.set("log_lines", saved_logs)
	main.set("card_resolution_timer", saved_timer)
	main.set("card_resolution_simultaneous_timer", saved_simultaneous_timer)
	main.set("card_resolution_auction_timer", saved_auction_timer)
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	main.set("card_resolution_auction_open", saved_auction_open)
	main.set("card_resolution_batch_locked", saved_batch_locked)
	main.set("card_resolution_batch_reference_player", saved_batch_reference)
	main.set("card_resolution_sequence", saved_sequence)
	main.set("last_card_resolution_player_index", saved_last_player)
	main.set("card_resolution_visual_id", saved_visual_id)
	main.set("card_resolution_visual_stage", saved_visual_stage)
	main.set("selected_player", saved_selected_player)
	main.set("selected_district", saved_selected_district)
	main.set("selected_card_resolution_id", saved_track_id)
	if saved_active.is_empty():
		main.call("_hide_card_resolution_overlay")
	else:
		main.call("_show_card_resolution_overlay", saved_active, saved_timer)
	main.call("_refresh_ui")
	return result


func _set_player_skill(main: Node, player_index: int, slot_index: int, skill_name: String) -> void:
	var players := _as_array(main.get("players"))
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
	main.set("players", players)


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
	var previous_players := _as_array(main.get("players")).duplicate(true)
	var previous_districts := _as_array(main.get("districts")).duplicate(true)
	var previous_log_lines := _as_array(main.get("log_lines")).duplicate(true)
	var previous_callouts := _as_array(main.get("action_callouts")).duplicate(true)
	var previous_selected_player := int(main.get("selected_player"))
	var previous_selected_district := int(main.get("selected_district"))
	var previous_selected_trade_product := String(main.get("selected_trade_product"))
	var previous_game_over := bool(main.get("game_over"))
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
	playable_skill["play_product"] = product_name
	playable_skill["play_flow_required"] = flow_before
	playable_skill["persistent"] = false
	slots[slot_index] = playable_skill
	player["slots"] = slots
	players[0] = player
	main.set("players", players)
	main.set("selected_player", 0)
	main.set("selected_district", district_index)
	main.set("selected_trade_product", product_name)
	main.set("game_over", false)
	_clear_player_cooldown(main, 0)
	var cash_before := _player_cash(_as_array(main.get("players")), 0)
	var can_play := bool(main.call("_can_play_skill_now", 0, playable_skill, false))
	var requirement_text := String(main.call("_skill_play_requirement_text", playable_skill, 0))
	main.call("_use_skill", slot_index)
	var players_after_play := _as_array(main.get("players"))
	var player_after_play := players_after_play[0] as Dictionary
	var slots_after_play := _as_array(player_after_play.get("slots", []))
	var districts_after_play := _as_array(main.get("districts"))
	var city_after_play := (districts_after_play[district_index] as Dictionary).get("city", {}) as Dictionary
	var play_ok := can_play \
		and requirement_text.contains(product_name) \
		and requirement_text.contains("不消耗商品") \
		and _player_cash(players_after_play, 0) > cash_before \
		and slot_index < slots_after_play.size() \
		and slots_after_play[slot_index] == null \
		and int(main.call("_player_product_flow", 0, product_name)) == flow_before \
		and _city_product_level(city_after_play, product_name) == product_level_before
	_clear_player_cooldown(main, 0)
	players_after_play = _as_array(main.get("players"))
	player_after_play = players_after_play[0] as Dictionary
	slots_after_play = _as_array(player_after_play.get("slots", [])).duplicate(true)
	var blocked_skill := main.call("_make_skill", "轨道融资1") as Dictionary
	blocked_skill.erase("starter_play_free")
	blocked_skill["play_product"] = "烟测缺货商品"
	blocked_skill["play_flow_required"] = 1
	blocked_skill["persistent"] = false
	slots_after_play[slot_index] = blocked_skill
	player_after_play["slots"] = slots_after_play
	players_after_play[0] = player_after_play
	main.set("players", players_after_play)
	var cash_before_blocked := _player_cash(_as_array(main.get("players")), 0)
	var blocked_can_play := bool(main.call("_can_play_skill_now", 0, blocked_skill, false))
	main.call("_use_skill", slot_index)
	var players_after_blocked := _as_array(main.get("players"))
	var blocked_player := players_after_blocked[0] as Dictionary
	var blocked_slots := _as_array(blocked_player.get("slots", []))
	var blocked_ok := not blocked_can_play \
		and slot_index < blocked_slots.size() \
		and blocked_slots[slot_index] != null \
		and String((blocked_slots[slot_index] as Dictionary).get("name", "")) == String(blocked_skill.get("name", "")) \
		and _player_cash(players_after_blocked, 0) == cash_before_blocked
	main.set("players", previous_players)
	main.set("districts", previous_districts)
	main.set("log_lines", previous_log_lines)
	main.set("action_callouts", previous_callouts)
	main.set("selected_player", previous_selected_player)
	main.set("selected_district", previous_selected_district)
	main.set("selected_trade_product", previous_selected_trade_product)
	main.set("game_over", previous_game_over)
	main.call("_refresh_ui")
	return play_ok and blocked_ok


func _verify_economy_card_effects(main: Node, district_index: int) -> void:
	main.set("selected_player", 0)
	main.set("selected_district", district_index)
	var districts := _as_array(main.get("districts"))
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
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(_city_product_level(city, product_name) == product_level_before + 1, "industry upgrade raises the lowest-level city product")
	_expect(int(city.get("revenue_bonus", 0)) == revenue_before + 25, "industry upgrade adds permanent city GDP/min revenue")

	var demands_for_shift := _as_array(city.get("demands", []))
	_expect(not demands_for_shift.is_empty(), "built city has demand products for product-shift testing")
	if not demands_for_shift.is_empty():
		var shift_target := String(demands_for_shift[0])
		var revenue_before_shift := int(city.get("revenue_bonus", 0))
		main.set("selected_trade_product", shift_target)
		_set_player_skill(main, 0, 2, "商品换线1")
		_clear_player_cooldown(main, 0)
		main.call("_use_skill", 2)
		districts = _as_array(main.get("districts"))
		city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
		_expect(_city_has_product(city, shift_target), "product line shift adds the selected trade product to the city")
		_expect(int(city.get("revenue_bonus", 0)) == revenue_before_shift + 18, "product line shift adds permanent city revenue")

	var demands_before_shift := _as_string_array(_as_array(city.get("demands", [])))
	if not demands_before_shift.is_empty():
		city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + 2
		districts[district_index]["city"] = city
		main.set("districts", districts)
		var damage_before_demand_shift := int(city.get("trade_route_damage", 0))
		var revenue_before_demand_shift := int(city.get("revenue_bonus", 0))
		main.set("selected_trade_product", product_name)
		_set_player_skill(main, 0, 2, "需求改造1")
		_clear_player_cooldown(main, 0)
		main.call("_use_skill", 2)
		districts = _as_array(main.get("districts"))
		city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
		var demands_after_shift := _as_string_array(_as_array(city.get("demands", [])))
		_expect(demands_after_shift != demands_before_shift, "demand redesign changes at least one city demand product")
		_expect(int(city.get("trade_route_damage", 0)) == damage_before_demand_shift - 1, "demand redesign repairs one route-damage pressure")
		_expect(int(city.get("revenue_bonus", 0)) == revenue_before_demand_shift + 10, "demand redesign adds permanent city revenue")

	main.set("selected_trade_product", product_name)
	var product_market := main.get("product_market") as Dictionary
	var entry := product_market.get(product_name, {}) as Dictionary
	entry["price"] = int(entry.get("base_price", 60))
	entry["trend"] = 0
	product_market[product_name] = entry
	main.set("product_market", product_market)
	var players_before_pump := _as_array(main.get("players"))
	var card_income_before := int((players_before_pump[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "价格套利1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	var players_after_pump := _as_array(main.get("players"))
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	var demand_pressure_after_pump := int(entry.get("temporary_demand_pressure", 0))
	_expect(demand_pressure_after_pump > 0, "price speculation creates temporary demand pressure instead of directly setting price")
	_expect(int((players_after_pump[0] as Dictionary).get("total_card_income", 0)) == card_income_before + 220, "price speculation records card-generated cash")

	_set_player_skill(main, 0, 2, "商品做空1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	var supply_pressure_after_short := int(entry.get("temporary_supply_pressure", 0))
	_expect(supply_pressure_after_short > 0, "short-selling card creates temporary supply pressure instead of directly setting price")

	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	var volatility_before := int(entry.get("volatility", 4))
	var demand_pressure_before_stabilize := int(entry.get("temporary_demand_pressure", 0))
	var supply_pressure_before_stabilize := int(entry.get("temporary_supply_pressure", 0))
	_set_player_skill(main, 0, 2, "市场稳定1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	_expect(int(entry.get("temporary_demand_pressure", 0)) < demand_pressure_before_stabilize or int(entry.get("temporary_supply_pressure", 0)) < supply_pressure_before_stabilize, "market stabilization reduces temporary supply/demand pressure")
	_expect(int(entry.get("volatility", volatility_before)) < volatility_before, "market stabilization permanently reduces product volatility")
	_expect(_as_array(entry.get("price_history", [])).size() >= 4, "product market records a visible price path across economic card effects")

	var contract_card_income_before := int((_as_array(main.get("players"))[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "远期采购1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	_expect(int(entry.get("market_contract_demand", 0)) >= 3, "forward-purchase card adds sustained product demand pressure")
	_expect(int(entry.get("market_contract_turns", 0)) >= 3, "forward-purchase card adds a visible product contract duration")
	_expect(String(main.call("_product_market_boon_text", product_name)).contains("商品合约"), "product contract appears in product economy weather text")
	var players_after_forward := _as_array(main.get("players"))
	_expect(int((players_after_forward[0] as Dictionary).get("total_card_income", 0)) == contract_card_income_before + 120, "forward-purchase product contract records card-generated cash")

	_set_player_skill(main, 0, 2, "期货套保1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	_expect(int(entry.get("market_contract_supply", 0)) >= 3, "futures hedge card adds sustained product supply pressure")
	_expect(String(main.call("_product_market_boon_text", product_name)).contains("供+"), "futures hedge supply pressure appears in product economy weather text")

	_set_player_skill(main, 0, 2, "包销协议1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	var market_contract_turns_before_age := int(entry.get("market_contract_turns", 0))
	_expect(int(entry.get("market_contract_demand", 0)) >= 4, "distribution contract card strengthens sustained product demand pressure")
	_expect(float(entry.get("route_flow_multiplier", 1.0)) >= 1.2, "distribution contract card accelerates related product route flow")

	_set_player_skill(main, 0, 2, "商品催化1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	var growth_turns_before_age := int(entry.get("growth_turns", 0))
	_expect(float(entry.get("growth_multiplier", 1.0)) >= 2.0, "product catalyst card boosts the selected product's positive growth multiplier")
	_expect(growth_turns_before_age >= 3, "product catalyst card adds a visible turn duration")
	_expect(String(main.call("_product_market_boon_text", product_name)).contains("增速"), "product catalyst appears in product economy weather text")
	var product_status_tags := main.call("_product_public_status_tags", product_name) as Array
	var product_status_text := String(main.call("_public_status_tag_text", product_status_tags))
	_expect(product_status_text.contains("商品合约") and product_status_text.contains("增速") and product_status_text.contains("商路"), "product weather and contracts appear as unified public status tags")

	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var route_damage_before := int(city.get("trade_route_damage", 0))
	_set_player_skill(main, 0, 2, "商路黑客1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(int(city.get("trade_route_damage", 0)) == route_damage_before + 1, "route sabotage adds persistent trade-route damage")

	var insured_revenue_before := int(city.get("revenue_bonus", 0))
	_set_player_skill(main, 0, 2, "供应链保险1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(int(city.get("trade_route_damage", 0)) == route_damage_before, "supply-chain insurance repairs one route-damage pressure")
	_expect(int(city.get("revenue_bonus", 0)) == insured_revenue_before + 30, "supply-chain insurance adds permanent city income")

	_set_player_skill(main, 0, 2, "短期订单1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var contract_turns_before_age := int(city.get("contract_turns", 0))
	var contract_breakdown := main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary
	_expect(int(city.get("contract_income_bonus", 0)) >= 95, "short-term order card adds a temporary city contract income bonus")
	_expect(contract_turns_before_age >= 3, "short-term order card adds a visible contract duration")
	_expect(int(contract_breakdown.get("contract", 0)) >= 95, "temporary city contract appears in city income breakdown")
	_expect(String(main.call("_city_contract_status_text", city)).contains("+"), "temporary city contract appears in city contract status text")

	var route_flow_before := float(city.get("route_flow_multiplier", 1.0))
	_set_player_skill(main, 0, 2, "星港快线1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var route_flow_turns_before_age := int(city.get("route_flow_turns", 0))
	_expect(float(city.get("route_flow_multiplier", 1.0)) >= maxf(1.45, route_flow_before), "route-flow card accelerates the selected owned city's commercial flow")
	_expect(route_flow_turns_before_age >= 3, "route-flow card adds a visible turn duration")
	_expect(String(main.call("_city_route_flow_status_text", city)).contains("×"), "route-flow card appears in city flow status text")
	var city_status_tags := main.call("_city_public_status_tags", city) as Array
	var city_status_text := String(main.call("_public_status_tag_text", city_status_tags))
	_expect(city_status_text.contains("城市合约") and city_status_text.contains("流通") and city_status_text.contains("永久收入"), "city contracts, flow, and permanent income appear as unified public status tags")

	var damage_penalty_before := int((main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary).get("damage_penalty", 0))
	var gdp_breakdown_before_damage := main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary
	main.call("_record_city_gdp_snapshot", district_index, int(gdp_breakdown_before_damage.get("net", 0)), gdp_breakdown_before_damage, "烟测受损前")
	districts = _as_array(main.get("districts"))
	var original_damage := int((districts[district_index] as Dictionary).get("damage", 0))
	(districts[district_index] as Dictionary)["damage"] = original_damage + 2
	main.set("districts", districts)
	var gdp_breakdown_after_damage := main.call("_city_cycle_income_breakdown", district_index, int(city.get("competition_matches", 0))) as Dictionary
	var damage_penalty_after := int(gdp_breakdown_after_damage.get("damage_penalty", 0))
	_expect(damage_penalty_after > damage_penalty_before, "district damage is reflected as a GDP penalty in city income breakdown")
	main.call("_record_city_gdp_snapshot", district_index, int(gdp_breakdown_after_damage.get("net", 0)), gdp_breakdown_after_damage, "烟测受损后")
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(_as_array(city.get("gdp_history", [])).size() >= 2, "city records a public GDP history across economy snapshots")
	_expect(int(city.get("last_gdp_delta", 0)) < 0, "city GDP history records the damage-driven GDP drop")
	_expect(String(main.call("_city_gdp_trend_text", city)).contains("GDP趋势"), "city GDP trend helper produces readable public trend text")
	_expect(String(main.call("_economy_overview_text")).contains("GDP趋势"), "economy overview exposes city GDP trend text")
	_expect(String(main.call("_region_codex_text", district_index)).contains("GDP趋势"), "region codex exposes city GDP trend text")
	districts = _as_array(main.get("districts"))
	(districts[district_index] as Dictionary)["damage"] = original_damage
	main.set("districts", districts)

	var gdp_baseline := int(main.call("_city_cycle_income", district_index, int(city.get("competition_matches", 0))))
	var gdp_card_income_before := int((_as_array(main.get("players"))[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "城市买涨1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(_as_array(city.get("gdp_derivatives", [])).size() >= 1, "city long-GDP card attaches an anonymous GDP derivative to the selected city")
	var long_derivative := _as_array(city.get("gdp_derivatives", []))[0] as Dictionary
	_expect(float(long_derivative.get("duration_seconds", 0.0)) >= 60.0 and float(long_derivative.get("expires_at", 0.0)) > float(main.get("game_time")), "city long-GDP derivative records a real-time holding window")
	main.call("_resolve_city_gdp_derivatives", district_index, gdp_baseline + 140, "烟测到期上涨", true)
	var players_after_long := _as_array(main.get("players"))
	_expect(int((players_after_long[0] as Dictionary).get("total_card_income", 0)) > gdp_card_income_before, "city long-GDP derivative pays out after a timed holding window when city GDP rises")

	var short_income_before := int((players_after_long[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "城市做空1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var short_derivative := _as_array(city.get("gdp_derivatives", []))[0] as Dictionary
	_expect(float(short_derivative.get("duration_seconds", 0.0)) >= 60.0 and float(short_derivative.get("expires_at", 0.0)) > float(main.get("game_time")), "city short-GDP derivative records a real-time holding window")
	main.call("_resolve_city_gdp_derivatives", district_index, maxi(0, gdp_baseline - 120), "烟测到期下跌", true)
	var players_after_short := _as_array(main.get("players"))
	_expect(int((players_after_short[0] as Dictionary).get("total_card_income", 0)) > short_income_before, "city short-GDP derivative pays out after a timed holding window when city GDP falls")

	districts = _as_array(main.get("districts")).duplicate(true)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var original_owner := int(city.get("owner", 0))
	city["owner"] = 1
	city["gdp_derivatives"] = []
	(districts[district_index] as Dictionary)["city"] = city
	main.set("districts", districts)
	_set_player_skill(main, 0, 2, "灾害保单1")
	_clear_player_cooldown(main, 0)
	var rejected_insurance: bool = main.call("_use_skill", 2) == true
	districts = _as_array(main.get("districts")).duplicate(true)
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(not rejected_insurance and _as_array(city.get("gdp_derivatives", [])).is_empty(), "disaster-insurance GDP hedge can only be placed on the player's own city")
	city["owner"] = original_owner
	(districts[district_index] as Dictionary)["city"] = city
	main.set("districts", districts)
	var insurance_income_before := int((_as_array(main.get("players"))[0] as Dictionary).get("total_card_income", 0))
	_set_player_skill(main, 0, 2, "灾害保单1")
	_clear_player_cooldown(main, 0)
	main.call("_use_skill", 2)
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var insurance_derivative := _as_array(city.get("gdp_derivatives", []))[0] as Dictionary
	_expect(insurance_derivative.get("insurance", false) == true and String(insurance_derivative.get("direction", "")) == "down", "disaster-insurance card records a defensive GDP hedge")
	main.call("_resolve_city_gdp_derivatives", district_index, maxi(0, gdp_baseline - 150), "烟测保单赔付", true)
	var players_after_insurance := _as_array(main.get("players"))
	_expect(int((players_after_insurance[0] as Dictionary).get("total_card_income", 0)) > insurance_income_before, "disaster-insurance card pays when the insured city GDP falls")

	main.call("_age_economic_boons", 30.0)
	product_market = main.get("product_market") as Dictionary
	entry = product_market.get(product_name, {}) as Dictionary
	districts = _as_array(main.get("districts"))
	city = (districts[district_index] as Dictionary).get("city", {}) as Dictionary
	_expect(int(entry.get("growth_turns", 0)) == maxi(0, growth_turns_before_age - 1), "temporary product-growth boon counts down after an economy age tick")
	_expect(int(entry.get("market_contract_turns", 0)) == maxi(0, market_contract_turns_before_age - 1), "temporary product contract counts down after an economy age tick")
	_expect(int(city.get("route_flow_turns", 0)) == maxi(0, route_flow_turns_before_age - 1), "temporary route-flow boon counts down after an economy age tick")
	_expect(int(city.get("contract_turns", 0)) == maxi(0, contract_turns_before_age - 1), "temporary city contract counts down after an economy age tick")
	var player_after_economy := _as_array(main.get("players"))[0] as Dictionary
	_expect(String(main.call("_player_cash_path_text", player_after_economy)).contains("→"), "economy helpers keep a multi-step recent cash path for overview menus")
	_clear_player_cooldown(main, 0)


func _verify_monster_resource_and_collision_system(main: Node, district_index: int) -> void:
	var districts := _as_array(main.get("districts"))
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
	var matches := _as_array(main.call("_monster_resource_matches", resource_actor, district_index))
	_expect(matches.has(focus_product), "monster resource matching detects district goods")
	var damage_before := int(((main.get("districts") as Array)[district_index] as Dictionary).get("damage", 0))
	var drained := int(main.call("_auto_monster_resource_drain", resource_actor, district_index, "烟测资源"))
	var districts_after_drain := main.get("districts") as Array
	var district_after_drain := districts_after_drain[district_index] as Dictionary
	_expect(drained == 2, "resource drain applies the monster's resource-damage value")
	_expect(int(district_after_drain.get("damage", 0)) == damage_before + 2, "resource drain damages the district/city HP track")
	_expect(String(district_after_drain.get("last_damage_source", "")).contains("资源吸取"), "district records the latest monster resource damage source")
	_expect(_map_effects_contain(main, "stomp"), "monster resource damage emits a temporary stomp map animation")

	districts = _as_array(main.get("districts"))
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
		for district_variant in _as_array(main.get("districts")):
			path_damage_before += int((district_variant as Dictionary).get("damage", 0))
		var walking_damage := int(main.call("_apply_auto_monster_path_effects", walking_actor, from_position, to_position, "烟测步行", "walk"))
		var path_damage_after_walk := 0
		for district_variant in _as_array(main.get("districts")):
			path_damage_after_walk += int((district_variant as Dictionary).get("damage", 0))
		var flying_actor := walking_actor.duplicate(true)
		flying_actor["movement_traits"] = ["flying"]
		var flying_damage := int(main.call("_apply_auto_monster_path_effects", flying_actor, from_position, to_position, "烟测飞行", "fly"))
		var path_damage_after_fly := 0
		for district_variant in _as_array(main.get("districts")):
			path_damage_after_fly += int((district_variant as Dictionary).get("damage", 0))
		_expect(walking_damage > 0 and path_damage_after_walk > path_damage_before, "walking monster path movement crushes regions")
		_expect(flying_damage == 0 and path_damage_after_fly == path_damage_after_walk, "flying monster path movement does not crush regions")

	var ocean_index := -1
	var land_index := -1
	districts = _as_array(main.get("districts"))
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
		_expect(float(main.call("_monster_terrain_move_multiplier", aquatic_actor, ocean_index)) > float(main.call("_monster_terrain_move_multiplier", aquatic_actor, land_index)), "aquatic monster movement is faster in ocean than on land")

	auto_monsters = _as_array(main.get("auto_monsters"))
	var target_before := auto_monsters[1] as Dictionary
	var target_durability_before := int(target_before.get("hp", 0)) + int(target_before.get("armor", 0))
	var hit := bool(main.call("_auto_monster_use_action_on_other", 0, 1, {
		"name": "烟测撞击",
		"range": 110.0,
		"damage": 2,
		"knockback": 120.0,
		"text": "烟测用的近距离撞击。",
	}, "烟测遭遇"))
	auto_monsters = _as_array(main.get("auto_monsters"))
	var target_after := auto_monsters[1] as Dictionary
	var target_durability_after := int(target_after.get("hp", 0)) + int(target_after.get("armor", 0))
	_expect(hit, "monster encounter action resolves against another monster")
	_expect(target_durability_after < target_durability_before, "monster encounter action reduces target durability through HP or armor")
	_expect(_map_effects_contain(main, "melee"), "monster encounter action emits a temporary melee attack animation")
	var districts_after_hit := main.get("districts") as Array
	var total_damage_after_hit := 0
	for district_variant in districts_after_hit:
		var damage_district := district_variant as Dictionary
		total_damage_after_hit += int(damage_district.get("damage", 0))
	_expect(total_damage_after_hit > damage_before + 2, "monster knockback collision damages at least one region")


func _verify_special_monster_passives(main: Node) -> void:
	var saved_auto_monsters := _as_array(main.get("auto_monsters")).duplicate(true)
	var saved_game_over := bool(main.get("game_over"))
	var saved_special_monster_timer := float(main.get("special_monster_timer"))
	var saved_log_lines := _as_array(main.get("log_lines")).duplicate(true)
	var saved_action_callouts := _as_array(main.get("action_callouts")).duplicate(true)
	var start_district := maxi(0, int(main.get("selected_district")))

	main.set("game_over", false)
	var mebius_index := int(main.call("_monster_catalog_index_by_name", "梦比优斯"))
	_expect(mebius_index >= 0, "monster catalog contains Mebius")
	if mebius_index >= 0:
		var mebius := main.call("_make_auto_monster", 0, mebius_index, start_district) as Dictionary
		mebius["hp"] = 18
		main.set("auto_monsters", [mebius])
		main.call("_auto_monster_take_damage", 0, 3, "烟测梦比姆炸弹", -1)
		var mebius_after := (_as_array(main.get("auto_monsters"))[0]) as Dictionary
		_expect(int(mebius_after.get("hp", 0)) == 15, "Mebius Bomb self-damage reduces Mebius HP by 3")
		_expect(bool(main.call("_is_auto_mebius_energy_active", 0)), "Mebius Energy activates at 15 HP")
		_expect(bool(mebius_after.get("mebius_energy_announced", false)), "Mebius Energy activation is announced once")

	var hikari_index := int(main.call("_monster_catalog_index_by_name", "希卡利"))
	_expect(hikari_index >= 0, "monster catalog contains Hikari")
	if hikari_index >= 0:
		var hikari := main.call("_make_auto_monster", 0, hikari_index, start_district) as Dictionary
		hikari["hp"] = 20
		main.set("auto_monsters", [hikari])
		main.call("_maybe_announce_auto_hikari_revenge_armor", 0)
		var hikari_active := (_as_array(main.get("auto_monsters"))[0]) as Dictionary
		_expect(bool(hikari_active.get("hikari_revenge_armor_active", false)), "Hikari Revenge Armor activates at 20 HP")
		_expect(int(main.call("_auto_monster_damage_bonus_from_passives", 0)) == 1, "Hikari Revenge Armor grants +1 outgoing damage")
		var hikari_hp_before := int(hikari_active.get("hp", 0))
		main.call("_auto_monster_take_damage", 0, 3, "烟测近战", -1)
		var hikari_after := (_as_array(main.get("auto_monsters"))[0]) as Dictionary
		_expect(hikari_hp_before - int(hikari_after.get("hp", 0)) == 2, "Hikari Revenge Armor reduces incoming damage by 1")

	main.set("auto_monsters", saved_auto_monsters)
	main.set("game_over", saved_game_over)
	main.set("special_monster_timer", saved_special_monster_timer)
	main.set("log_lines", saved_log_lines)
	main.set("action_callouts", saved_action_callouts)


func _verify_card_art_script() -> void:
	var script := load(CARD_ART_SCRIPT_PATH)
	_expect(script != null, "card art script loads")
	if script == null:
		return
	var card_view := script.new() as Control
	_expect(card_view != null, "card art script instantiates a Control")
	if card_view != null:
		get_root().add_child(card_view)
		card_view.call("set_card", "怪兽·尸套龙1", "monster_card", "怪兽卡 / 召唤", Color("#fb7185"), 1, false, "HP50｜95s｜移190m｜怪区邻接")
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
			"尸套龙",
			"自动怪兽",
			40,
			0,
			"190m",
			{
				"accent": Color("#94a3b8"),
				"secondary": Color("#e2e8f0"),
				"glyph": "瘴",
				"motif": "miasma",
				"subtitle": "临时美工",
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
		if String(district.get("terrain", "")) == "land" and city.is_empty():
			return i
	return -1


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _map_effects_contain(main: Node, kind: String) -> bool:
	for effect_variant in _as_array(main.get("map_event_effects")):
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		if String(effect.get("kind", "")) == kind:
			return true
	return false


func _map_effects_contain_style(main: Node, kind: String, style: String) -> bool:
	for effect_variant in _as_array(main.get("map_event_effects")):
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		if String(effect.get("kind", "")) == kind and String(effect.get("card_style", "")) == style:
			return true
	return false


func _map_effects_contain_min_duration(main: Node, kind: String, min_duration: float) -> bool:
	for effect_variant in _as_array(main.get("map_event_effects")):
		if not (effect_variant is Dictionary):
			continue
		var effect := effect_variant as Dictionary
		if String(effect.get("kind", "")) == kind and float(effect.get("duration", 0.0)) >= min_duration:
			return true
	return false


func _regions_start_with_single_goods(main: Node) -> bool:
	var districts := _as_array(main.get("districts"))
	var saw_land := false
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		if String(district.get("terrain", "")) != "land":
			if (district.get("products", []) as Array).size() != 0:
				return false
			continue
		saw_land = true
		if (district.get("products", []) as Array).size() != 1:
			return false
		if (district.get("demands", []) as Array).size() != 1:
			return false
	return saw_land


func _city_has_single_goods(main: Node, district_index: int) -> bool:
	var districts := _as_array(main.get("districts"))
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
	var business_names := _as_array(main.call("_card_codex_names", "business"))
	var economy_names := _as_array(main.call("_card_codex_names", "economy"))
	var all_names := _as_array(main.call("_card_codex_names", "all"))
	var monster_skill := main.call("_skill_definition", monster_card) as Dictionary
	var contract_skill := main.call("_skill_definition", "区域供需合约1") as Dictionary
	var monster_text := String(main.call("_card_codex_text", monster_card, monster_skill, 0, maxi(1, monster_names.size())))
	var contract_text := String(main.call("_card_codex_text", "区域供需合约1", contract_skill, 0, maxi(1, business_names.size())))
	var ok := true
	ok = ok and monster_names.has(monster_card)
	ok = ok and business_names.has("区域供需合约1")
	ok = ok and economy_names.has("远期采购1")
	ok = ok and all_names.has(monster_card)
	ok = ok and all_names.has("区域供需合约1")
	ok = ok and String(main.call("_card_codex_filter_label", "monster")) == "怪兽牌"
	ok = ok and String(main.call("_card_codex_filter_label", "business")) == "经营/合约"
	ok = ok and monster_text.contains("分类：怪兽牌")
	ok = ok and contract_text.contains("分类：经营/合约")
	return ok


func _verify_area_trade_contract_card_variants(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var ok := true
	var source_index := _first_empty_land_district_for_contract(main)
	var target_index := _first_empty_land_district_for_contract(main, [source_index])
	if source_index < 0 or target_index < 0:
		return false
	ok = ok and bool(main.call("_create_city_at_district_for_player", 0, source_index, "合约牌谱供给", false))
	ok = ok and bool(main.call("_create_city_at_district_for_player", 1, target_index, "合约牌谱需求", false))
	var districts := _as_array(main.get("districts")).duplicate(true)
	var source_district := districts[source_index] as Dictionary
	var source_city := source_district.get("city", {}) as Dictionary
	source_city["products"] = [{"name": "真空可可", "level": 1}]
	source_city["demands"] = ["离子香料"]
	source_district["products"] = ["真空可可"]
	source_district["demands"] = ["离子香料"]
	source_district["city"] = source_city
	districts[source_index] = source_district
	var target_district := districts[target_index] as Dictionary
	var target_city := target_district.get("city", {}) as Dictionary
	target_city["products"] = [{"name": "梦境香氛", "level": 1}]
	target_city["demands"] = ["重力陶瓷"]
	target_district["products"] = ["梦境香氛"]
	target_district["demands"] = ["重力陶瓷"]
	target_district["city"] = target_city
	districts[target_index] = target_district
	main.set("districts", districts)
	main.set("selected_trade_product", "活体芯片")
	var selected_skill := main.call("_make_skill", "区域供需合约1") as Dictionary
	var auto_skill := main.call("_make_skill", "自动撮合合约1") as Dictionary
	var fixed_skill := main.call("_make_skill", "环晶电池专供1") as Dictionary
	var multi_skill := main.call("_make_skill", "双边对冲合约1") as Dictionary
	var punitive_skill := main.call("_make_skill", "惩罚性拒签条款1") as Dictionary
	var selected_products := _as_string_array(_as_array(main.call("_area_trade_contract_products", selected_skill, source_index, target_index)))
	var auto_products := _as_string_array(_as_array(main.call("_area_trade_contract_products", auto_skill, source_index, target_index)))
	var fixed_products := _as_string_array(_as_array(main.call("_area_trade_contract_products", fixed_skill, source_index, target_index)))
	var multi_products := _as_string_array(_as_array(main.call("_area_trade_contract_products", multi_skill, source_index, target_index)))
	var punitive_context := main.call("_area_trade_contract_context", punitive_skill, 0, source_index, target_index) as Dictionary
	var business_names := _as_array(main.call("_card_codex_names", "business"))
	ok = ok and selected_products.size() == 1 and selected_products[0] == "活体芯片"
	ok = ok and auto_products.size() >= 1 and auto_products[0] == "真空可可" and not auto_products.has("活体芯片")
	ok = ok and fixed_products.size() == 1 and fixed_products[0] == "环晶电池"
	ok = ok and multi_products.size() >= 2 and multi_products.has("活体芯片") and multi_products.has("真空可可")
	ok = ok and String(punitive_context.get("error", "")) == ""
	ok = ok and int(punitive_skill.get("decline_cash_penalty", 0)) >= 180 and int(punitive_skill.get("decline_route_damage", 0)) >= 2
	for name in ["自动撮合合约1", "环晶电池专供1", "双边对冲合约1", "惩罚性拒签条款1"]:
		var card_name := String(name)
		var family := _skill_family(card_name)
		ok = ok and business_names.has(card_name)
		ok = ok and int(main.call("_card_price", "%s4" % family)) == int(main.call("_card_price", "%s1" % family))
	var restore_result := int(main.call("_apply_run_state", saved))
	return ok and restore_result == OK


func _first_empty_land_district_for_contract(main: Node, excluded: Array = []) -> int:
	var districts := _as_array(main.get("districts"))
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
	var districts := _as_array(main.get("districts")).duplicate(true)
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
	main.set("districts", districts)
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
	var districts := _as_array(main.get("districts"))
	var source_city := (districts[source_index] as Dictionary).get("city", {}) as Dictionary
	var target_city := (districts[target_index] as Dictionary).get("city", {}) as Dictionary
	var source_products := _test_city_product_names(source_city)
	var target_demands := _test_city_demand_names(target_city)
	var market := main.get("product_market") as Dictionary
	for product_variant in market.keys():
		var product_name := String(product_variant)
		if product_name != "" and not source_products.has(product_name) and not target_demands.has(product_name):
			return product_name
	for product_variant in market.keys():
		var product_name := String(product_variant)
		if product_name != "":
			return product_name
	return "环晶电池"


func _verify_area_trade_contract_accept_and_decline(main: Node) -> bool:
	var saved := main.call("_capture_run_state") as Dictionary
	var saved_force_duration: float = float(main.get("card_resolution_force_duration"))
	var saved_force_simultaneous: float = float(main.get("card_resolution_force_simultaneous_window"))
	var ok := true
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("pending_contract_offers", [])
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_force_duration", 5.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	var land_pair := _prepare_land_pair_for_contract_test(main)
	var source_index := int(land_pair.get("source", -1))
	var target_index := int(land_pair.get("target", -1))
	if source_index < 0 or target_index < 0:
		ok = false
	else:
		var players := _as_array(main.get("players"))
		for i in range(players.size()):
			var player := players[i] as Dictionary
			player["cash"] = 5000
			players[i] = player
		main.set("players", players)
		ok = ok and bool(main.call("_create_city_at_district_for_player", 0, source_index, "合约测试供给", false))
		ok = ok and bool(main.call("_create_city_at_district_for_player", 1, target_index, "合约测试需求", false))
		var product_name := _test_contract_product(main, source_index, target_index)
		var flow_districts := _as_array(main.get("districts")).duplicate(true)
		var flow_source_district := flow_districts[source_index] as Dictionary
		var flow_source_city := flow_source_district.get("city", {}) as Dictionary
		var flow_demands := _as_array(flow_source_city.get("demands", [])).duplicate(true)
		if not flow_demands.has(product_name):
			flow_demands.append(product_name)
		flow_source_city["demands"] = flow_demands
		flow_source_district["city"] = flow_source_city
		flow_districts[source_index] = flow_source_district
		main.set("districts", flow_districts)
		var skill := main.call("_make_skill", "区域供需合约1") as Dictionary
		skill["play_product"] = product_name
		skill["play_flow_required"] = 1
		var missing_pair_context := main.call("_area_trade_contract_context", skill, 0, -1, -1) as Dictionary
		ok = ok and String(missing_pair_context.get("error", "")) != ""
		var queue_players := _as_array(main.get("players"))
		var queue_player := queue_players[0] as Dictionary
		var queue_slots := _as_array(queue_player.get("slots", []))
		if queue_slots.is_empty():
			queue_slots.append(null)
		queue_slots[0] = skill.duplicate(true)
		queue_player["slots"] = queue_slots
		queue_players[0] = queue_player
		main.set("players", queue_players)
		main.set("selected_player", 0)
		main.set("selected_trade_product", product_name)
		main.set("selected_contract_source_district", -1)
		main.set("selected_contract_target_district", -1)
		ok = ok and not bool(main.call("_queue_skill_resolution", 0, 0, -1))
		ok = ok and _as_array(main.get("card_resolution_queue")).is_empty() and _as_array(main.get("pending_contract_offers")).is_empty()
		main.set("selected_district", source_index)
		main.call("_set_selected_contract_source_district")
		main.set("selected_district", target_index)
		main.call("_set_selected_contract_target_district")
		ok = ok and int(main.get("selected_contract_source_district")) == source_index
		ok = ok and int(main.get("selected_contract_target_district")) == target_index
		main.set("selected_trade_product", product_name)
		var context := main.call("_area_trade_contract_context", skill, 0, source_index, target_index) as Dictionary
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
		main.set("selected_player", target_owner)
		main.call("_refresh_ui")
		var player_box := main.get("player_box") as VBoxContainer
		ok = ok and player_box != null and not _container_label_text_contains(player_box, "匿名合约签署窗口")
		main.set("active_card_resolution", {})
		main.set("card_resolution_timer", 0.0)

		main.set("selected_player", 0)
		ok = ok and bool(main.call("_queue_skill_resolution", 0, 0, -1))
		ok = ok and _as_array(main.get("pending_contract_offers")).is_empty()
		ok = ok and (main.get("active_card_resolution") as Dictionary).is_empty()
		main.call("_update_card_resolution_queue", 0.49)
		ok = ok and _as_array(main.get("pending_contract_offers")).is_empty()
		main.call("_update_card_resolution_queue", 0.02)
		var active_contract_reveal := main.get("active_card_resolution") as Dictionary
		ok = ok and not active_contract_reveal.is_empty()
		ok = ok and int(active_contract_reveal.get("contract_source_district", -1)) == source_index
		ok = ok and int(active_contract_reveal.get("contract_target_district", -1)) == target_index
		ok = ok and _as_array(main.get("pending_contract_offers")).is_empty()
		main.set("selected_player", target_owner)
		main.call("_refresh_ui")
		player_box = main.get("player_box") as VBoxContainer
		ok = ok and player_box != null and not _container_label_text_contains(player_box, "匿名合约签署窗口")
		main.call("_update_card_resolution_queue", 4.90)
		ok = ok and _as_array(main.get("pending_contract_offers")).is_empty()
		ok = ok and not (main.get("active_card_resolution") as Dictionary).is_empty()
		main.call("_update_card_resolution_queue", 0.20)
		var pending_offers := _as_array(main.get("pending_contract_offers"))
		ok = ok and pending_offers.size() == 1
		ok = ok and not bool(main.call("_is_card_resolution_busy"))
		var queued_contract_id := -1
		if not pending_offers.is_empty():
			var queued_offer := pending_offers[0] as Dictionary
			queued_contract_id = int(queued_offer.get("resolution_id", queued_offer.get("contract_offer_id", -1)))
			ok = ok and is_equal_approx(float(queued_offer.get("contract_decision_timer", 0.0)), 5.0)
		_set_player_skill(main, 2, 40, "舆论操控1")
		main.set("selected_player", 2)
		ok = ok and bool(main.call("_queue_skill_resolution", 2, 40, -1))
		ok = ok and _as_array(main.get("pending_contract_offers")).size() == 1
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
		main.set("selected_player", target_owner)
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
		var players_before_accept := _as_array(main.get("players"))
		var target_cash_before := int((players_before_accept[target_owner] as Dictionary).get("cash", 0))
		main.call("_respond_to_active_contract", true)
		ok = ok and _as_array(main.get("pending_contract_offers")).is_empty()
		var stored_accept := main.call("_card_resolution_entry_by_id", queued_contract_id) as Dictionary
		ok = ok and String(stored_accept.get("contract_response", "")) == "accepted"
		ok = ok and bool(stored_accept.get("public_owner_revealed", false)) and (stored_accept.get("guessers", []) as Array).has(2)
		var districts_after_accept := _as_array(main.get("districts"))
		var source_district := districts_after_accept[source_index] as Dictionary
		var target_district := districts_after_accept[target_index] as Dictionary
		var source_city := source_district.get("city", {}) as Dictionary
		var target_city := target_district.get("city", {}) as Dictionary
		ok = ok and ((source_district.get("products", []) as Array).has(product_name) or _test_city_product_names(source_city).has(product_name))
		ok = ok and ((target_district.get("demands", []) as Array).has(product_name) or _test_city_demand_names(target_city).has(product_name))
		var players_after_accept := _as_array(main.get("players"))
		ok = ok and int((players_after_accept[target_owner] as Dictionary).get("cash", 0)) > target_cash_before
		ok = ok and float(target_city.get("route_flow_multiplier", 1.0)) > 1.0

		var decline_skill := main.call("_make_skill", "区域供需合约2") as Dictionary
		var decline_entry := entry.duplicate(true)
		decline_entry["resolution_id"] = 90002
		decline_entry["skill"] = decline_skill.duplicate(true)
		decline_entry["contract_response"] = "pending"
		var players_before_decline := _as_array(main.get("players"))
		var decline_cash_before := int((players_before_decline[target_owner] as Dictionary).get("cash", 0))
		ok = ok and bool(main.call("_apply_area_trade_contract", players_before_decline[0] as Dictionary, decline_skill, decline_entry))
		ok = ok and _as_array(main.get("pending_contract_offers")).size() == 1
		main.call("_respond_to_active_contract", false)
		var players_after_decline := _as_array(main.get("players"))
		ok = ok and int((players_after_decline[target_owner] as Dictionary).get("cash", 0)) < decline_cash_before
		var districts_after_decline := _as_array(main.get("districts"))
		var declined_city := ((districts_after_decline[target_index] as Dictionary).get("city", {}) as Dictionary)
		ok = ok and int(declined_city.get("trade_route_damage", 0)) >= 1

		var timeout_entry := entry.duplicate(true)
		timeout_entry["resolution_id"] = 90003
		timeout_entry["skill"] = decline_skill.duplicate(true)
		timeout_entry["contract_response"] = "pending"
		var players_before_timeout := _as_array(main.get("players"))
		var timeout_cash_before := int((players_before_timeout[target_owner] as Dictionary).get("cash", 0))
		ok = ok and bool(main.call("_apply_area_trade_contract", players_before_timeout[0] as Dictionary, decline_skill, timeout_entry))
		main.call("_update_pending_contract_offers", 5.1)
		ok = ok and _as_array(main.get("pending_contract_offers")).is_empty()
		var players_after_timeout := _as_array(main.get("players"))
		ok = ok and int((players_after_timeout[target_owner] as Dictionary).get("cash", 0)) < timeout_cash_before
		var ai_entry := entry.duplicate(true)
		var punitive_skill := main.call("_make_skill", "惩罚性拒签条款1") as Dictionary
		ai_entry["resolution_id"] = 90004
		ai_entry["skill"] = punitive_skill.duplicate(true)
		ai_entry["contract_response"] = "pending"
		var ai_samples_before := _ai_decision_sample_count(_as_array(main.get("players")))
		ok = ok and bool(main.call("_apply_area_trade_contract", _as_array(main.get("players"))[0] as Dictionary, punitive_skill, ai_entry))
		ok = ok and _as_array(main.get("pending_contract_offers")).size() == 1
		var ai_contract_responses := int(main.call("_update_ai_contract_responses", true))
		ok = ok and ai_contract_responses == 1 and _as_array(main.get("pending_contract_offers")).is_empty()
		ok = ok and _ai_decision_sample_count(_as_array(main.get("players"))) > ai_samples_before
	var restore_result := int(main.call("_apply_run_state", saved))
	main.set("card_resolution_force_duration", saved_force_duration)
	main.set("card_resolution_force_simultaneous_window", saved_force_simultaneous)
	return ok and restore_result == OK


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


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
