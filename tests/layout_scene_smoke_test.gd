extends SceneTree

const SCENE_PATHS := [
	"res://scenes/GameScreen.tscn",
	"res://scenes/CardUI.tscn",
	"res://scenes/LayoutDemo.tscn",
]

const SPLIT_UI_SCENE_PATHS := [
	"res://scenes/ui/GameScreen.tscn",
	"res://scenes/ui/TopBar.tscn",
	"res://scenes/ui/PlanetBoard.tscn",
	"res://scenes/ui/PlayerBoard.tscn",
	"res://scenes/ui/HandRack.tscn",
	"res://scenes/ui/CardFace.tscn",
	"res://scenes/ui/RightInspector.tscn",
	"res://scenes/ui/ActionDock.tscn",
	"res://scenes/ui/BidBoard.tscn",
	"res://scenes/ui/DistrictInfoPanel.tscn",
	"res://scenes/ui/PublicTrack.tscn",
	"res://scenes/ui/CardTrack.tscn",
	"res://scenes/ui/FirstRunCoach.tscn",
	"res://scenes/ui/ScenarioBrowser.tscn",
	"res://scenes/ui/ScenarioCoach.tscn",
	"res://scenes/ui/ScenarioActionLog.tscn",
	"res://scenes/ui/ScenarioReplayPanel.tscn",
	"res://scenes/ui/CampaignMenu.tscn",
	"res://scenes/ui/CampaignBriefing.tscn",
	"res://scenes/ui/CampaignProgressMap.tscn",
	"res://scenes/ui/CampaignRewardPanel.tscn",
	"res://scenes/ui/MatchRecapPanel.tscn",
	"res://scenes/ui/OverlayLayer.tscn",
	"res://scenes/ui/CardResolutionBanner.tscn",
	"res://scenes/ui/BottomCountdownBar.tscn",
	"res://scenes/ui/DistrictSupplyDrawer.tscn",
	"res://scenes/ui/DistrictSupplyMarketCard.tscn",
	"res://scenes/ui/DistrictSupplyPreviewCard.tscn",
	"res://scenes/ui/FullscreenMapOverlay.tscn",
	"res://scenes/ui/MenuOverlay.tscn",
	"res://scenes/ui/TutorialQuickStartBoard.tscn",
	"res://scenes/ui/RulesQuickReferenceBoard.tscn",
	"res://scenes/ui/RoleCodexIdentityBoard.tscn",
	"res://scenes/ui/CompendiumHubBoard.tscn",
	"res://scenes/ui/CardCodexBrowser.tscn",
	"res://scenes/ui/CardCodexDetail.tscn",
	"res://scenes/ui/RegionCodexDetail.tscn",
	"res://scenes/ui/ProductCodexDetail.tscn",
	"res://scenes/ui/BestiaryDetail.tscn",
	"res://scenes/ui/EconomyDashboard.tscn",
	"res://scenes/ui/IntelDossierBoard.tscn",
	"res://scenes/ui/StandingsScoreboard.tscn",
	"res://scenes/ui/FinalSettlementBoard.tscn",
	"res://scenes/ui/MenuRootLobby.tscn",
	"res://scenes/ui/NewGameSetupLobby.tscn",
	"res://scenes/ui/NewGameSetupOptionBoard.tscn",
	"res://scenes/ui/NewGameSetupSeatCard.tscn",
	"res://scenes/ui/NewGameSetupSeatIdentityBoard.tscn",
]

const SPLIT_UI_SCRIPT_PATHS := [
	"res://scripts/ui/game_screen.gd",
	"res://scripts/ui/top_bar.gd",
	"res://scripts/ui/player_board.gd",
	"res://scripts/ui/hand_rack.gd",
	"res://scripts/ui/card_face.gd",
	"res://scripts/ui/right_inspector.gd",
	"res://scripts/ui/action_dock.gd",
	"res://scripts/ui/bid_board.gd",
	"res://scripts/ui/district_info_panel.gd",
	"res://scripts/ui/card_track.gd",
	"res://scripts/ui/first_run_coach.gd",
	"res://scripts/ui/scenario_browser.gd",
	"res://scripts/ui/scenario_coach.gd",
	"res://scripts/ui/scenario_action_log.gd",
	"res://scripts/ui/scenario_replay_panel.gd",
	"res://scripts/ui/campaign_menu.gd",
	"res://scripts/ui/campaign_briefing.gd",
	"res://scripts/ui/campaign_progress_map.gd",
	"res://scripts/ui/campaign_reward_panel.gd",
	"res://scripts/ui/match_recap_panel.gd",
	"res://scripts/ui/bottom_countdown_bar.gd",
	"res://scripts/ui/district_supply_market_card.gd",
	"res://scripts/ui/district_supply_preview_card.gd",
	"res://scripts/ui/menu_overlay.gd",
	"res://scripts/ui/tutorial_quick_start_board.gd",
	"res://scripts/ui/rules_quick_reference_board.gd",
	"res://scripts/ui/role_codex_identity_board.gd",
	"res://scripts/ui/compendium_hub_board.gd",
	"res://scripts/ui/card_codex_browser.gd",
	"res://scripts/ui/card_codex_detail.gd",
	"res://scripts/ui/region_codex_detail.gd",
	"res://scripts/ui/product_codex_detail.gd",
	"res://scripts/ui/bestiary_detail.gd",
	"res://scripts/ui/economy_dashboard.gd",
	"res://scripts/ui/intel_dossier_board.gd",
	"res://scripts/ui/standings_scoreboard.gd",
	"res://scripts/ui/final_settlement_board.gd",
	"res://scripts/ui/menu_root_lobby.gd",
	"res://scripts/ui/new_game_setup_lobby.gd",
	"res://scripts/ui/new_game_setup_option_board.gd",
	"res://scripts/ui/new_game_setup_seat_card.gd",
	"res://scripts/ui/new_game_setup_seat_identity_board.gd",
]

const VIEWMODEL_SCRIPT_PATHS := [
	"res://scripts/viewmodels/action_dock_snapshot.gd",
	"res://scripts/viewmodels/bid_board_snapshot.gd",
	"res://scripts/viewmodels/overlay_layer_snapshot.gd",
	"res://scripts/viewmodels/card_codex_browser_snapshot.gd",
	"res://scripts/viewmodels/card_codex_detail_snapshot.gd",
	"res://scripts/viewmodels/top_bar_snapshot.gd",
	"res://scripts/viewmodels/right_inspector_snapshot.gd",
	"res://scripts/viewmodels/public_track_snapshot.gd",
	"res://scripts/viewmodels/planet_board_snapshot.gd",
	"res://scripts/viewmodels/table_snapshot.gd",
	"res://scripts/viewmodels/first_run_coach_snapshot.gd",
	"res://scripts/viewmodels/scenario_browser_snapshot.gd",
	"res://scripts/viewmodels/scenario_coach_snapshot.gd",
	"res://scripts/viewmodels/scenario_action_log_snapshot.gd",
	"res://scripts/viewmodels/scenario_replay_panel_snapshot.gd",
	"res://scripts/viewmodels/campaign_menu_snapshot.gd",
	"res://scripts/viewmodels/campaign_briefing_snapshot.gd",
	"res://scripts/viewmodels/campaign_progress_map_snapshot.gd",
	"res://scripts/viewmodels/campaign_reward_snapshot.gd",
	"res://scripts/viewmodels/match_recap_snapshot.gd",
	"res://scripts/viewmodels/player_board_snapshot.gd",
	"res://scripts/viewmodels/card_view_snapshot.gd",
	"res://scripts/viewmodels/district_view_snapshot.gd",
]

const VIEWPORT_SIZES := [
	Vector2(1280, 720),
	Vector2(1366, 768),
	Vector2(1600, 960),
	Vector2(1920, 1080),
	Vector2(2560, 1440),
]

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists("res://themes/GameTheme.tres"), "GameTheme exists")
	_expect(ResourceLoader.exists("res://scripts/HandLayout.gd"), "HandLayout script exists")
	_expect(ResourceLoader.exists("res://scripts/CardUI.gd"), "CardUI script exists")
	for script_path in SPLIT_UI_SCRIPT_PATHS:
		_expect(ResourceLoader.exists(script_path), "%s exists" % script_path)
	for script_path in VIEWMODEL_SCRIPT_PATHS:
		_expect(ResourceLoader.exists(script_path), "%s exists" % script_path)
	for path in SCENE_PATHS:
		await _check_scene_loads(path)
	for path in SPLIT_UI_SCENE_PATHS:
		await _check_scene_loads(path, path.ends_with("OverlayLayer.tscn"))
	_check_main_player_panel_refresh_contract()
	await _check_game_screen_structure()
	await _check_first_run_coach_component()
	await _check_split_game_screen_structure()
	await _check_split_game_screen_data_binding()
	await _check_menu_overlay_shell_component()
	await _check_tutorial_quick_start_board_component()
	await _check_rules_quick_reference_board_component()
	await _check_role_codex_identity_board_component()
	await _check_compendium_hub_board_component()
	await _check_card_codex_browser_component()
	await _check_card_codex_detail_component()
	await _check_region_codex_detail_component()
	await _check_product_codex_detail_component()
	await _check_bestiary_detail_component()
	await _check_economy_dashboard_component()
	await _check_intel_dossier_board_component()
	await _check_standings_scoreboard_component()
	await _check_final_settlement_board_component()
	await _check_runtime_table_snapshot_bridge()
	await _check_core_layout_no_overlap()
	await _check_map_view_projection_defaults()
	_check_code_layer_contracts()
	_check_viewmodel_contracts()
	await _check_hand_layout_counts()
	await _check_hand_rack_v3_interaction_contract()
	await _check_card_face_presentation_specs()
	await _check_empty_player_board_affordance()
	_finish()


func _check_scene_loads(path: String, allow_canvas_layer: bool = false) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads" % path)
	if packed == null:
		return
	for viewport_size in VIEWPORT_SIZES:
		var instance: Node = packed.instantiate()
		_expect(instance is Control or (allow_canvas_layer and instance is CanvasLayer), "%s root is Control%s" % [path, " or CanvasLayer" if allow_canvas_layer else ""])
		if instance is Control:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
			root.add_child(viewport)
			var control := instance as Control
			viewport.add_child(control)
			await process_frame
			_expect(not _has_forbidden_2d_ui(control), "%s has no Node2D/Sprite2D UI nodes" % path)
			_expect(control.get_combined_minimum_size().x <= viewport_size.x and control.get_combined_minimum_size().y <= viewport_size.y, "%s minimum layout fits %.0fx%.0f" % [path, viewport_size.x, viewport_size.y])
			viewport.remove_child(control)
			root.remove_child(viewport)
			viewport.queue_free()
		elif allow_canvas_layer and instance is CanvasLayer:
			root.add_child(instance)
			await process_frame
			_expect(not _has_forbidden_2d_ui(instance), "%s has no Node2D/Sprite2D UI nodes" % path)
			root.remove_child(instance)
		instance.queue_free()


func _check_game_screen_structure() -> void:
	var packed := load("res://scenes/GameScreen.tscn")
	if packed == null:
		return
	var screen: Node = packed.instantiate()
	root.add_child(screen)
	await process_frame
	for node_name in ["TopBar", "TableRow", "LeftInfoPanel", "CenterTablePanel", "RightInfoPanel", "PlayerPanel", "OverlayLayer", "HandArea"]:
		_expect(screen.find_child(node_name, true, false) != null, "GameScreen contains %s" % node_name)
	root.remove_child(screen)
	screen.queue_free()


func _check_first_run_coach_component() -> void:
	var packed := load("res://scenes/ui/FirstRunCoach.tscn") as PackedScene
	_expect(packed != null, "FirstRunCoach scene loads")
	if packed == null:
		return
	var coach := packed.instantiate() as Control
	root.add_child(coach)
	await process_frame
	_expect(coach.has_method("set_coach") and coach.has_signal("primary_action_requested"), "FirstRunCoach exposes data binding and one primary action signal")
	var emitted_actions: Array[String] = []
	if coach.has_signal("primary_action_requested"):
		coach.connect("primary_action_requested", func(action_id: String) -> void:
			emitted_actions.append(action_id)
		)
	var snapshot_script := load("res://scripts/viewmodels/first_run_coach_snapshot.gd")
	var first_snapshot: Dictionary = snapshot_script.new().apply_dictionary({
		"visible": true,
		"progress": {
			"selected_district": false,
			"has_monster": false,
			"has_city": false,
			"has_opened_supply": false,
			"has_bought_card": false,
			"has_played_card": false,
			"has_seen_public_track": false,
			"has_seen_clues": false,
		},
	}).to_ui_dictionary()
	coach.call("set_coach", first_snapshot)
	await process_frame
	var button := coach.find_child("CoachPrimaryButton", true, false) as Button
	var visible_buttons := _visible_button_count(coach)
	_expect(button != null and button.visible and not button.disabled and (button.text.contains("点") or button.text.contains("确认")), "FirstRunCoach renders a single visible next-step CTA for the current phase")
	_expect(visible_buttons == 1, "FirstRunCoach keeps exactly one visible CTA in expanded mode")
	if button != null:
		button.emit_signal("pressed")
		await process_frame
	if emitted_actions.is_empty() and coach.has_method("_on_primary_button_pressed"):
		coach.call("_on_primary_button_pressed")
		await process_frame
	_expect(emitted_actions.has("coach_select_district"), "FirstRunCoach primary CTA emits the normalized coach action id")
	var folded_snapshot: Dictionary = snapshot_script.new().apply_dictionary({
		"visible": true,
		"progress": {
			"selected_district": true,
			"has_monster": true,
			"has_city": true,
			"has_opened_supply": true,
			"has_bought_card": true,
			"has_played_card": true,
			"has_seen_public_track": true,
			"has_seen_clues": false,
		},
		"auto_fold_when_track_seen": true,
	}).to_ui_dictionary()
	coach.call("set_coach", folded_snapshot)
	await process_frame
	var collapsed := coach.find_child("CoachCollapsed", true, false) as Control
	_expect(collapsed != null and collapsed.visible and _node_tree_text(coach).contains("首局引导完成"), "FirstRunCoach auto-folds after the player has played a card and inspected the public track")
	_expect(_visible_button_count(coach) == 0, "FirstRunCoach collapsed mode removes primary CTA clutter")
	var clue_snapshot: Dictionary = snapshot_script.new().apply_dictionary({
		"progress": {
			"selected_district": true,
			"has_monster": true,
			"has_city": true,
			"has_opened_supply": true,
			"has_bought_card": true,
			"has_played_card": true,
			"has_seen_public_track": true,
			"has_seen_clues": false,
		},
		"auto_fold_when_track_seen": false,
	}).to_ui_dictionary()
	_expect(str(clue_snapshot.get("stage", "")) == "inspect_clues" and str(clue_snapshot.get("title", "")).contains("线索"), "FirstRunCoach stage model still includes the clue-inspection phase for non-folded/tutorial variants")
	root.remove_child(coach)
	coach.queue_free()


func _visible_button_count(node: Node) -> int:
	var count := 0
	if node is Button and (node as Button).visible and (node as Button).is_visible_in_tree():
		count += 1
	for child in node.get_children():
		count += _visible_button_count(child)
	return count


func _check_split_game_screen_structure() -> void:
	var packed := load("res://scenes/ui/GameScreen.tscn") as PackedScene
	if packed == null:
		return
	var screen: Node = packed.instantiate()
	root.add_child(screen)
	await process_frame
	for node_name in ["TopBar", "FirstGlanceRail", "IdentityChip", "CashChip", "GdpChip", "GoalChip", "SelectedDistrictChip", "PrimaryActionChip", "PublicTrack", "FirstRunCoach", "CoachPrimaryButton", "ScenarioCoach", "ScenarioCoachPrimaryButton", "TrackFocusRibbon", "TrackFocusLabel", "PlanetBoard", "PlanetStageViewport", "MapHost", "PlanetLeftSpaceRail", "PlanetRightSpaceRail", "LeftRailStack", "RightRailStack", "RightInspector", "InspectorReasonPanel", "InspectorRequirementChipRow", "DistrictInfoPanel", "CurrentActionPanel", "EventLogLabel", "InspectorDeepLinkRow", "PlayerBoard", "PlayerThreeSecondRail", "PlayerHandCountChip", "PlayerGoalBar", "PlayerBidBoard", "BidBoardChipRow", "BidBoardActionRow", "PlayerMainActionDock", "ActionDockQuickActionRow", "PlayerStatusLampRow", "PlayerReadinessChipRow", "OverlayLayer", "TooltipLayer", "SideDrawerLayer", "ModalLayer", "DragPreviewLayer", "SideDrawerPanel", "DragDropTargetPanel", "DragDropTargetLabel", "DragPreviewPanel"]:
		_expect(screen.find_child(node_name, true, false) != null, "split GameScreen contains %s" % node_name)
	root.remove_child(screen)
	screen.queue_free()


func _check_split_game_screen_data_binding() -> void:
	var packed := load("res://scenes/ui/GameScreen.tscn") as PackedScene
	if packed == null:
		return
	var screen: Control = packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	_expect(screen.has_method("apply_state"), "split GameScreen exposes apply_state")
	screen.call("apply_state", {
		"top_bar": {"phase": "阶段｜竞价", "turn": "席位｜2/4", "identity": "赤港财团", "cash_text": "¥ 1300", "gdp_text": "+22/s", "goal_text": "5000", "selected_district": "雾港区", "primary_action": "首召"},
		"card_track": [
			{
				"id": "track_42",
				"resolution_id": 42,
				"card_name": "orbital_finance_i",
				"label": "公开牌",
				"slot": 1,
				"state": "current",
				"cost": "¥80",
				"kind": "anonymous",
				"title": "牌轨详情",
				"summary": "当前｜轨道融资｜归属:匿名",
				"detail": "报价、目标和余波是公开推理线索。",
				"full_detail": "公开牌槽保留卡面、报价、目标和余波；玩家在右侧详情中做竞猜，不在地图表面堆文字。",
				"why": "单击牌槽选中竞猜；双击打开卡牌详情。",
				"requirements": [{"text": "当前"}, {"text": "归属:匿名"}, {"text": "报价¥80"}],
				"actions": [{"id": "track_select_42", "label": "选中竞猜"}, {"id": "track_intel_42", "label": "线索档案"}, {"id": "track_open_orbital_finance_i", "label": "卡牌详情"}],
				"deep_links": [{"id": "track_intel_42", "label": "线索档案"}, {"id": "track_open_orbital_finance_i", "label": "卡牌详情"}],
				"select_action": "track_select_42",
				"open_action": "track_open_orbital_finance_i",
			},
			{"label": "公共事件", "slot": 2, "state": "queued", "kind": "event"},
		],
		"planet": {
			"title": "星球赌桌",
			"hint": "中央地图保留最大视觉中心",
			"left_rail": {
				"title": "地表情报",
				"entries": [
					{"label": "星区", "value": "8区", "active": true, "accent": Color("#38bdf8")},
					{"label": "选区", "value": "雾港区", "active": true, "accent": Color("#facc15")},
					{"label": "牌架", "value": "2张", "active": true, "accent": Color("#c084fc")},
				],
			},
			"right_rail": {
				"title": "外围压力",
				"entries": [
					{"label": "怪兽", "value": "3只", "active": true, "accent": Color("#fb7185")},
					{"label": "天气", "value": "预报", "active": true, "accent": Color("#38bdf8")},
					{"label": "牌轨", "value": "竞价2", "active": true, "accent": Color("#f59e0b")},
				],
			},
		},
		"district": {"title": "雾港区", "detail": "生产海雾果，需求轨迹墨水。", "chips": [{"text": "可看牌架"}]},
		"actions": [{"id": "build", "label": "建城"}, {"id": "market", "label": "牌架"}],
		"right_inspector": {
			"title": "当前说明",
			"why": "最近怪兽在本区，买牌可用。",
			"district": {
				"title": "雾港区",
				"summary": "海雾线升温｜牌架可看",
				"detail": "海雾线升温｜牌架可看",
				"full_detail": "海雾商品线正在升温。完整区域详情应进入抽屉，而不是常驻右侧主桌。这里还有供需、怪兽、牌架与历史线索。",
				"chips": [{"text": "怪兽邻近"}],
			},
			"requirements": [{"text": "怪兽半径 OK"}, {"text": "现金足够"}],
			"actions": [{"id": "buy", "label": "买牌"}],
			"deep_links": [{"id": "detail_region", "label": "区域详情"}],
			"logs": ["公开事件"],
		},
		"player_board": {
			"title": "玩家板｜测试手牌",
			"hint": "选中卡牌后在右侧详情执行。",
			"identity": "赤港财团",
			"cash_text": "¥ 1300",
			"gdp_text": "+22/s",
			"goal_text": "5000",
			"goal_ratio": 0.26,
			"quick_actions": [
				{"id": "build", "label": "建城", "state": "ready", "active": true},
				{"id": "rack", "label": "牌架", "state": "2张", "active": true},
				{"id": "buy", "label": "买牌", "state": "ready", "active": true},
				{"id": "play", "label": "出牌", "state": "waiting", "active": false},
			],
			"table_state_lamps": [
				{"text": "桌态", "state": "竞价", "active": true, "accent": Color("#f59e0b")},
				{"text": "本席", "state": "就绪", "active": true, "accent": Color("#38bdf8")},
			],
			"readiness_chips": [
				{"text": "选区就绪", "active": true, "accent": Color("#38bdf8")},
				{"text": "手牌 2/5", "active": false, "accent": Color("#c084fc")},
			],
			"bid_board": {
				"title": "牌桌竞价",
				"phase": "竞价 4s",
				"status": "候补牌参拍中｜当前¥40｜最高¥80",
				"active": true,
				"chips": [
					{"label": "我的", "state": "¥40", "active": true, "accent": Color("#fde68a")},
					{"label": "最高", "state": "¥80", "active": true, "accent": Color("#f59e0b")},
					{"label": "本批", "state": "2张", "active": true, "accent": Color("#c084fc")},
					{"label": "下批", "state": "0张", "active": false, "accent": Color("#38bdf8")},
				],
				"track_links": [
					{"id": "track_select_9002", "label": "领跑", "state": "竞拍1 ¥80", "active": true, "selected": true, "accent": Color("#f59e0b")},
					{"id": "track_select_9001", "label": "我的牌", "state": "竞拍2 ¥40", "active": true, "accent": Color("#fde68a")},
				],
				"actions": [
					{"id": "bid_plus_10", "label": "保守+10", "active": true, "accent": Color("#fde68a")},
					{"id": "bid_set_80", "label": "追平", "active": true, "accent": Color("#f59e0b")},
					{"id": "bid_set_90", "label": "压过", "active": true, "accent": Color("#22c55e")},
					{"id": "bid_reset", "label": "清零", "active": true, "accent": Color("#94a3b8")},
				],
			},
			"selected_district_summary": "雾港区",
			"primary_action": "首召",
			"actions": [{"id": "summon", "label": "首召"}, {"id": "market", "label": "牌架"}],
			"hand_cards": [
				{"id": "test_hand_0", "name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "现金流上升。"},
				{"id": "test_hand_1", "name": "相位否决", "cost": "1", "type": "互动", "rank": "I", "effect": "反制直接互动牌。"},
			],
		},
		"first_run_coach": {
			"visible": true,
			"progress": {
				"selected_district": true,
				"has_monster": false,
				"has_city": false,
				"has_opened_supply": false,
				"has_bought_card": false,
				"has_played_card": false,
				"has_seen_public_track": false,
				"has_seen_clues": false,
			},
			"primary_action": {"id": "coach_first_summon", "label": "在选区首召", "tooltip": "首召后开启附近牌架。"},
		},
	"logs": ["有人打出公开牌", "怪兽靠近雾港"],
	})
	await process_frame
	var top_bar := screen.find_child("TopBar", true, false)
	var right_inspector := screen.find_child("RightInspector", true, false)
	var player_board := screen.find_child("PlayerBoard", true, false)
	var hand_rack := screen.find_child("HandRack", true, false)
	var public_track := screen.find_child("PublicTrack", true, false) as Control
	var public_track_slot := screen.find_child("PublicTrackSlot", true, false) as Control
	var public_track_pip := screen.find_child("PublicTrackStatePip", true, false) as ColorRect
	var public_track_label := screen.find_child("PublicTrackSlotLabel", true, false) as Label
	var public_track_meta := screen.find_child("PublicTrackSlotMeta", true, false) as Label
	var first_run_coach := screen.find_child("FirstRunCoach", true, false)
	var first_run_coach_button := screen.find_child("CoachPrimaryButton", true, false) as Button
	var track_focus_ribbon := screen.find_child("TrackFocusRibbon", true, false) as Control
	var track_focus_label := screen.find_child("TrackFocusLabel", true, false) as Label
	var map_host := screen.find_child("MapHost", true, false) as Control
	var left_rail_title := screen.find_child("LeftRailTitle", true, false) as Label
	var right_rail_title := screen.find_child("RightRailTitle", true, false) as Label
	var left_rail_text := screen.find_child("LeftRailText", true, false) as Label
	var right_rail_text := screen.find_child("RightRailText", true, false) as Label
	var left_rail_entries := screen.find_children("PlanetLeftRailEntry*", "", true, false)
	var right_rail_entries := screen.find_children("PlanetRightRailEntry*", "", true, false)
	var inspector_title := screen.find_child("InspectorTitle", true, false) as Label
	var identity_chip := screen.find_child("IdentityChip", true, false) as Label
	var end_turn_button := screen.find_child("EndTurnButton", true, false) as Button
	var menu_button := screen.find_child("MenuButton", true, false) as Button
	var reason_panel := screen.find_child("InspectorReasonPanel", true, false) as Control
	var reason_label := screen.find_child("InspectorReasonLabel", true, false) as Label
	var requirement_row := screen.find_child("InspectorRequirementChipRow", true, false)
	var district_chip_row := screen.find_child("DistrictChipRow", true, false)
	var district_detail_label := screen.find_child("DistrictDetail", true, false) as Label
	var current_action_panel := screen.find_child("CurrentActionPanel", true, false)
	var inspector_action_row := current_action_panel.find_child("ActionRow", true, false) if current_action_panel != null else null
	var deep_link_row := screen.find_child("InspectorDeepLinkRow", true, false)
	var district_title := screen.find_child("DistrictTitle", true, false) as Label
	var side_drawer_panel := screen.find_child("SideDrawerPanel", true, false)
	var side_drawer_body_scroll := screen.find_child("SideDrawerBodyScroll", true, false) as ScrollContainer
	var side_drawer_section_list := screen.find_child("SideDrawerSectionList", true, false)
	var tooltip_layer := screen.find_child("TooltipLayer", true, false)
	var side_drawer_layer := screen.find_child("SideDrawerLayer", true, false)
	var modal_layer := screen.find_child("ModalLayer", true, false)
	var drag_preview_layer := screen.find_child("DragPreviewLayer", true, false)
	var tooltip_panel := screen.find_child("TooltipPanel", true, false)
	var confirm_panel := screen.find_child("ConfirmPanel", true, false)
	var side_drawer_summary := screen.find_child("SideDrawerSummary", true, false) as Label
	var side_drawer_action_row := screen.find_child("SideDrawerActionRow", true, false)
	var drag_drop_target_panel := screen.find_child("DragDropTargetPanel", true, false) as Control
	var drag_drop_target_label := screen.find_child("DragDropTargetLabel", true, false) as Label
	var drag_preview_panel := screen.find_child("DragPreviewPanel", true, false)
	var player_goal_bar := screen.find_child("PlayerGoalBar", true, false) as ProgressBar
	var player_hand_count_chip := screen.find_child("PlayerHandCountChip", true, false) as Label
	var player_bid_board := screen.find_child("PlayerBidBoard", true, false)
	var bid_board_chip_row := screen.find_child("BidBoardChipRow", true, false)
	var bid_board_action_row := screen.find_child("BidBoardActionRow", true, false)
	var player_main_action_dock := player_board.find_child("PlayerMainActionDock", true, false) if player_board != null else null
	var player_quick_action_row := player_main_action_dock.find_child("ActionDockQuickActionRow", true, false) if player_main_action_dock != null else null
	var player_status_lamp_row := screen.find_child("PlayerStatusLampRow", true, false)
	var player_readiness_chip_row := screen.find_child("PlayerReadinessChipRow", true, false)
	var player_action_row := player_main_action_dock.find_child("ActionRow", true, false) if player_main_action_dock != null else null
	_expect(top_bar != null, "split GameScreen top bar survives data binding")
	_expect(identity_chip != null and identity_chip.text.contains("赤港财团"), "split TopBar binds first-glance player identity")
	_expect(menu_button != null, "split TopBar exposes a first-screen menu button")
	_expect(end_turn_button != null and not end_turn_button.visible, "split TopBar keeps end-turn controls hidden by default so PlayerBoard remains the single main-action dock")
	_expect(right_inspector != null and right_inspector.has_method("set_context"), "split GameScreen routes context through RightInspector")
	_expect(reason_panel != null and reason_panel.visible, "split RightInspector shows the reason panel only when why/requirements exist")
	_expect(reason_label != null and reason_label.text.contains("买牌可用"), "split RightInspector binds why/availability text")
	_expect(requirement_row != null and requirement_row.get_child_count() == 2, "split RightInspector binds requirement chips")
	_check_right_inspector_collapses_empty_panels(screen, "split sample GameScreen")
	_expect(deep_link_row != null and deep_link_row.get_child_count() == 1, "split RightInspector binds Codex/detail links")
	_expect(district_detail_label != null and district_detail_label.text.contains("海雾线升温") and not district_detail_label.text.contains("完整区域详情"), "split RightInspector shows a short table summary instead of full region prose")
	_expect(side_drawer_panel != null and not side_drawer_panel.visible, "split OverlayLayer owns a hidden side drawer for 30-second detail")
	_expect(side_drawer_body_scroll != null and side_drawer_section_list != null, "split OverlayLayer side drawer has a scrollable section list for 30-second detail")
	_expect(tooltip_layer != null and side_drawer_layer != null and modal_layer != null and drag_preview_layer != null, "split OverlayLayer exposes explicit tooltip, drawer, modal, and drag-preview layers")
	_expect(tooltip_panel != null and tooltip_panel.get_parent() == tooltip_layer, "split OverlayLayer hosts TooltipPanel under TooltipLayer")
	_expect(side_drawer_panel != null and side_drawer_panel.get_parent().get_parent().get_parent() == side_drawer_layer, "split OverlayLayer hosts SideDrawerPanel under SideDrawerLayer")
	_expect(confirm_panel != null and confirm_panel.get_parent().get_parent() == modal_layer, "split OverlayLayer hosts ConfirmPanel under ModalLayer")
	_expect(drag_preview_panel != null, "split OverlayLayer owns a drag-preview layer")
	_expect(drag_drop_target_panel != null and drag_drop_target_label != null, "split OverlayLayer owns a drag-drop target hint under the preview layer")
	_expect(player_board != null, "split GameScreen player board survives data binding")
	_expect(player_goal_bar != null and player_goal_bar.value > 25.0, "split PlayerBoard binds goal progress")
	_expect(player_hand_count_chip != null and player_hand_count_chip.text.contains("手牌") and player_hand_count_chip.text.contains("2/5"), "split PlayerBoard exposes current hand count in the 3-second layer")
	_expect(player_bid_board != null, "split PlayerBoard exposes a separate BidBoard above the main action dock")
	_expect(bid_board_chip_row != null and bid_board_chip_row.get_child_count() >= 4, "split BidBoard binds bid/highest/current-batch/next-batch chips")
	_expect(bid_board_action_row != null and bid_board_action_row.get_child_count() >= 3, "split BidBoard binds chip-like bid action buttons")
	_expect(player_bid_board != null and _node_tree_text(player_bid_board).contains("领跑") and _node_tree_text(player_bid_board).contains("我的牌"), "split BidBoard shows compact public-track pointers beside bid controls")
	_expect(player_main_action_dock != null, "split PlayerBoard exposes one main action dock")
	_expect(player_quick_action_row != null and player_quick_action_row.get_child_count() == 4, "split PlayerBoard binds Build/Rack/Buy/Play scan buttons inside the single main action dock")
	_expect(player_status_lamp_row != null and player_status_lamp_row.get_child_count() == 1, "split PlayerBoard binds table-state lamps from snapshot data")
	_expect(player_readiness_chip_row != null and player_readiness_chip_row.get_child_count() == 1, "split PlayerBoard binds action-readiness chips from snapshot data")
	_expect(player_action_row != null and player_action_row.get_child_count() == 2, "split PlayerBoard binds compact primary action buttons inside the single main action dock")
	_expect(public_track != null and public_track.custom_minimum_size.y <= 48.0, "split PublicTrack remains a thin public offer rail")
	_expect(first_run_coach != null and first_run_coach_button != null and first_run_coach_button.text.contains("首召"), "split GameScreen binds FirstRunCoach below the public track with a single next-step CTA")
	_expect(public_track_slot != null and public_track_slot.custom_minimum_size.y <= 36.0, "split PublicTrack renders compact public slots instead of full cards")
	_expect(public_track_pip != null, "split PublicTrack renders a compact state color pip")
	_expect(public_track_label != null and public_track_label.text.contains("公开牌"), "split PublicTrack binds the public card short label")
	_expect(public_track_meta != null and public_track_meta.text.contains("待猜"), "split PublicTrack keeps ownership as a scan-first guess hint")
	_expect(public_track != null and public_track.find_child("CardFace", true, false) == null, "split PublicTrack does not render full CardFace nodes")
	_expect(track_focus_ribbon != null and track_focus_label != null and not track_focus_ribbon.visible, "split GameScreen owns a hidden table-focus ribbon for temporary public-track/BidBoard context")
	if public_track_slot != null:
		var pre_hover_title := inspector_title.text if inspector_title != null else ""
		var pre_hover_reason := reason_label.text if reason_label != null else ""
		public_track_slot.emit_signal("mouse_entered")
		await process_frame
		_expect(inspector_title != null and not inspector_title.text == pre_hover_title and district_title != null and public_track_label != null and district_title.text.contains(public_track_label.text), "split PublicTrack hover previews the public card slot in RightInspector")
		_expect(reason_label != null and not reason_label.text == pre_hover_reason and reason_label.text.strip_edges() != "", "split PublicTrack hover shows public card-state reasoning instead of leaving the region explanation in place")
		_expect(track_focus_ribbon != null and track_focus_ribbon.visible and track_focus_label != null and track_focus_label.text.contains("牌轨对照") and track_focus_label.text.contains("公开牌") and track_focus_label.text.contains("报价"), "split PublicTrack hover opens a short table-focus ribbon that connects the public slot to public bid context")
		public_track_slot.emit_signal("mouse_exited")
		await process_frame
		_expect(inspector_title != null and inspector_title.text == pre_hover_title and reason_label != null and reason_label.text == pre_hover_reason, "split PublicTrack unhover restores the prior RightInspector context")
		_expect(track_focus_ribbon != null and not track_focus_ribbon.visible, "split PublicTrack unhover clears the temporary table-focus ribbon when no track card is selected")
	_expect(left_rail_title != null and left_rail_title.text == "地表情报" and right_rail_title != null and right_rail_title.text == "外围压力", "split PlanetBoard binds public side-rail titles from snapshot data")
	_expect(left_rail_entries.size() == 3 and right_rail_entries.size() == 3, "split PlanetBoard renders data-driven public intelligence and outer-pressure side-rail entries")
	_expect(left_rail_text != null and not left_rail_text.visible and right_rail_text != null and not right_rail_text.visible, "split PlanetBoard hides static side-rail fallback labels after snapshot binding")
	_expect(_node_tree_text(left_rail_entries[0]).contains("星区") and _node_tree_text(left_rail_entries[0]).contains("8区"), "split PlanetBoard left rail shows scan-first district count")
	_expect(_node_tree_text(right_rail_entries[0]).contains("怪兽") and _node_tree_text(right_rail_entries[2]).contains("牌轨"), "split PlanetBoard right rail shows scan-first outer pressure and public track state")
	_expect(hand_rack != null and hand_rack.get_child_count() == 2, "split HandRack receives card data")
	if hand_rack != null and hand_rack.get_child_count() > 0:
		var first_hand_card := hand_rack.get_child(0)
		var first_hand_card_data: Dictionary = first_hand_card.call("get_card_data") if first_hand_card.has_method("get_card_data") else {}
		_expect(first_hand_card.name.begins_with("MiniHandCardFace"), "split HandRack renders bottom cards as named MiniCard faces")
		_expect(first_hand_card_data.get("presentation") == "mini_hand" and first_hand_card_data.get("detail_policy") == "right_inspector", "split HandRack defaults hand cards to MiniCard presentation with RightInspector detail policy")
	_expect(hand_rack != null and hand_rack.has_signal("card_hovered"), "split HandRack exposes card hover for the inspector layer")
	_expect(hand_rack != null and hand_rack.has_signal("card_unhovered"), "split HandRack exposes card unhover for restoring the inspector layer")
	_expect(hand_rack != null and hand_rack.has_signal("card_drag_preview_started") and hand_rack.has_signal("card_drag_preview_ended") and hand_rack.has_signal("card_drag_released"), "split HandRack exposes card drag preview and release signals")
	_expect(player_board != null and player_board.has_signal("card_hovered"), "split PlayerBoard forwards hand hover without rebuilding the rack")
	_expect(player_board != null and player_board.has_signal("card_unhovered") and screen.has_signal("card_unhovered"), "split PlayerBoard and GameScreen forward hand unhover to restore context")
	_expect(player_board != null and player_board.has_signal("card_drag_preview_started") and player_board.has_signal("card_drag_released") and screen.has_signal("card_drag_preview_started") and screen.has_signal("card_drop_requested"), "split PlayerBoard and GameScreen forward card drag preview/drop intent without touching rules")
	if hand_rack != null and hand_rack.has_signal("card_hovered") and hand_rack.has_signal("card_unhovered"):
		var hover_first_child_id := -1
		if hand_rack.get_child_count() > 0:
			hover_first_child_id = hand_rack.get_child(0).get_instance_id()
		var hover_data: Dictionary = {"name": "轨道融资", "type": "经济", "cost": "2", "rank": "I", "effect": "现金流上升。"}
		hand_rack.emit_signal("card_hovered", hover_data)
		await process_frame
		var hover_after_child_id := -2
		if hand_rack.get_child_count() > 0:
			hover_after_child_id = hand_rack.get_child(0).get_instance_id()
		_expect(inspector_title != null and inspector_title.text.contains("卡牌"), "split HandRack hover previews card detail in RightInspector")
		_expect(district_title != null and district_title.text.contains("轨道融资") and reason_label != null and reason_label.text.contains("现金流"), "split RightInspector card hover shows the hovered card effect")
		_expect(hover_first_child_id == hover_after_child_id, "split HandRack hover updates RightInspector without rebuilding hand cards")
		hand_rack.emit_signal("card_unhovered")
		await process_frame
		_expect(inspector_title != null and inspector_title.text == "当前说明", "split HandRack unhover restores the prior RightInspector context")
		_expect(reason_label != null and reason_label.text.contains("买牌可用"), "split RightInspector restores why/availability text after hand-card unhover")
	if hand_rack != null and hand_rack.has_signal("card_drag_preview_started"):
		var drag_preview_label: Label = screen.find_child("DragPreviewLabel", true, false) as Label
		var preview_data: Dictionary = {"name": "轨道融资", "type": "经济", "cost": "2"}
		var blocked_preview_data: Dictionary = {
			"name": "轨道融资",
			"type": "经济",
			"cost": "2",
			"actionable": false,
			"drop_enabled": false,
			"play_state": "冷却中",
			"drop_label": "不能出：冷却中",
			"block_reason": "玩家行动冷却0.8s。",
		}
		hand_rack.emit_signal("card_drag_preview_started", preview_data, Vector2(4000, 4000))
		await process_frame
		var visible_size: Vector2 = Vector2(screen.get_viewport().get_visible_rect().size)
		var preview_size := Vector2(maxf(drag_preview_panel.size.x, drag_preview_panel.custom_minimum_size.x), maxf(drag_preview_panel.size.y, drag_preview_panel.custom_minimum_size.y))
		var preview_right: float = drag_preview_panel.position.x + maxf(drag_preview_panel.size.x, drag_preview_panel.custom_minimum_size.x)
		var preview_bottom: float = drag_preview_panel.position.y + maxf(drag_preview_panel.size.y, drag_preview_panel.custom_minimum_size.y)
		_expect(drag_preview_panel != null and drag_preview_panel.visible and drag_preview_label != null and drag_preview_label.text.contains("轨道融资"), "split HandRack drag preview signal renders a card preview in OverlayLayer")
		_expect(drag_preview_panel != null and drag_preview_panel.get_parent() == drag_preview_layer, "split OverlayLayer hosts DragPreviewPanel under DragPreviewLayer")
		_expect(preview_size.x <= 220.0 and preview_size.y <= 220.0, "split OverlayLayer keeps drag preview as a compact card-sized overlay instead of a tall blocking panel (%s)" % preview_size)
		_expect(preview_right <= visible_size.x + 1.0 and preview_bottom <= visible_size.y + 1.0, "split OverlayLayer clamps drag preview inside the viewport")
		_expect(drag_drop_target_panel != null and drag_drop_target_panel.visible and drag_drop_target_label != null and drag_drop_target_label.text.contains("拖到星球地图"), "split drag preview highlights the map target as required when the cursor is off-board")
		if hand_rack.has_signal("card_drag_preview_moved") and map_host != null:
			hand_rack.emit_signal("card_drag_preview_moved", preview_data, map_host.get_global_rect().get_center())
			await process_frame
			_expect(drag_drop_target_panel != null and drag_drop_target_panel.visible and drag_drop_target_label != null and drag_drop_target_label.text.contains("松开出牌") and drag_preview_label != null and drag_preview_label.text.contains("松开出牌"), "split drag preview switches to an accepting map-drop state over MapHost")
			hand_rack.emit_signal("card_drag_preview_moved", blocked_preview_data, map_host.get_global_rect().get_center())
			await process_frame
			_expect(drag_drop_target_panel != null and drag_drop_target_panel.visible and drag_drop_target_label != null and drag_drop_target_label.text.contains("冷却中") and drag_preview_label != null and drag_preview_label.text.contains("不能出"), "split drag preview shows rule-state block reasons over MapHost instead of a generic map hint")
			_expect(drag_drop_target_label != null and drag_drop_target_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and drag_drop_target_label.vertical_alignment == VERTICAL_ALIGNMENT_TOP, "map drop-target label stays on the target edge instead of covering the planet center")
			if drag_preview_panel is Control:
				var map_rect := map_host.get_global_rect()
				var planet_core_rect := Rect2(
					map_rect.position + Vector2(map_rect.size.x * 0.24, map_rect.size.y * 0.08),
					Vector2(map_rect.size.x * 0.52, map_rect.size.y * 0.84)
				)
				var preview_rect := (drag_preview_panel as Control).get_global_rect()
				var preview_left_of_map := preview_rect.position.x + preview_rect.size.x <= map_rect.position.x - 4.0
				var preview_right_of_map := preview_rect.position.x >= map_rect.position.x + map_rect.size.x + 4.0
				_expect(not preview_rect.intersects(planet_core_rect), "invalid drag preview docks away from the central planet core")
				_expect(preview_left_of_map or preview_right_of_map, "invalid drag preview uses the map side lane instead of hovering over the globe")
		hand_rack.emit_signal("card_drag_preview_ended", preview_data)
		await process_frame
		_expect(drag_preview_panel != null and not drag_preview_panel.visible, "split HandRack drag preview end hides OverlayLayer preview")
		_expect(drag_drop_target_panel != null and not drag_drop_target_panel.visible, "split HandRack drag preview end hides the map drop-target hint")
	if hand_rack != null and hand_rack.has_signal("card_drag_released") and screen.has_signal("card_drop_requested") and map_host != null:
		var drop_requests: Array = []
		screen.connect("card_drop_requested", func(card_data: Dictionary, screen_position: Vector2) -> void:
			drop_requests.append({"card": card_data, "position": screen_position})
		)
		hand_rack.emit_signal("card_drag_released", {"id": "hand_0", "name": "轨道融资"}, Vector2(-80, -80))
		await process_frame
		_expect(drop_requests.is_empty(), "split GameScreen ignores a hand-card release outside MapHost")
		hand_rack.emit_signal("card_drag_released", {
			"id": "hand_blocked",
			"name": "轨道融资",
			"actionable": false,
			"drop_enabled": false,
			"block_reason": "玩家行动冷却0.8s。",
		}, map_host.get_global_rect().get_center())
		await process_frame
		_expect(drop_requests.is_empty(), "split GameScreen blocks a release over MapHost when the hand-card play state is not actionable")
		hand_rack.emit_signal("card_drag_released", {"id": "hand_0", "name": "轨道融资", "actionable": true, "drop_enabled": true}, map_host.get_global_rect().get_center())
		await process_frame
		var first_drop: Dictionary = drop_requests[0] if drop_requests.size() > 0 and drop_requests[0] is Dictionary else {}
		var dropped_card: Dictionary = first_drop.get("card", {}) if first_drop.get("card", {}) is Dictionary else {}
		_expect(drop_requests.size() == 1 and dropped_card.get("id") == "hand_0", "split GameScreen turns a hand-card release over MapHost into a card_drop_requested intent")
	var first_hand_child_id := -1
	if hand_rack != null and hand_rack.get_child_count() > 0:
		first_hand_child_id = hand_rack.get_child(0).get_instance_id()
	var hovered_hand_child_id := -1
	if hand_rack != null and hand_rack.get_child_count() > 0 and hand_rack.has_method("set_hovered_card"):
		var first_hover_card := hand_rack.get_child(0) as Control
		if first_hover_card != null:
			hand_rack.call("set_hovered_card", first_hover_card)
			await process_frame
			if hand_rack.has_method("get_hovered_card"):
				var hovered_variant: Variant = hand_rack.call("get_hovered_card")
				if hovered_variant is Control:
					hovered_hand_child_id = (hovered_variant as Control).get_instance_id()
	var first_quick_action_id := -1
	if player_quick_action_row != null and player_quick_action_row.get_child_count() > 0:
		first_quick_action_id = player_quick_action_row.get_child(0).get_instance_id()
	var first_status_lamp_id := -1
	if player_status_lamp_row != null and player_status_lamp_row.get_child_count() > 0:
		first_status_lamp_id = player_status_lamp_row.get_child(0).get_instance_id()
	var first_readiness_chip_id := -1
	if player_readiness_chip_row != null and player_readiness_chip_row.get_child_count() > 0:
		first_readiness_chip_id = player_readiness_chip_row.get_child(0).get_instance_id()
	var first_primary_action_id := -1
	if player_action_row != null and player_action_row.get_child_count() > 0:
		first_primary_action_id = player_action_row.get_child(0).get_instance_id()
	var first_requirement_chip_id := -1
	if requirement_row != null and requirement_row.get_child_count() > 0:
		first_requirement_chip_id = requirement_row.get_child(0).get_instance_id()
	var first_district_chip_id := -1
	if district_chip_row != null and district_chip_row.get_child_count() > 0:
		first_district_chip_id = district_chip_row.get_child(0).get_instance_id()
	var first_inspector_action_id := -1
	if inspector_action_row != null and inspector_action_row.get_child_count() > 0:
		first_inspector_action_id = inspector_action_row.get_child(0).get_instance_id()
	var first_deep_link_id := -1
	if deep_link_row != null and deep_link_row.get_child_count() > 0:
		first_deep_link_id = deep_link_row.get_child(0).get_instance_id()
	var first_public_track_slot_id := -1
	if public_track_slot != null:
		first_public_track_slot_id = public_track_slot.get_instance_id()
	screen.call("apply_state", {
		"top_bar": {"identity": "赤港财团", "cash_text": "¥ 1400", "gdp_text": "+24/s", "goal_text": "5000", "selected_district": "雾港区", "primary_action": "首召"},
		"card_track": [
			{
				"id": "track_42",
				"resolution_id": 42,
				"card_name": "orbital_finance_i",
				"label": "公开牌",
				"slot": 1,
				"state": "current",
				"cost": "¥80",
				"kind": "anonymous",
				"title": "牌轨详情",
				"summary": "当前｜轨道融资｜归属:匿名",
				"detail": "报价、目标和余波是公开推理线索。",
				"full_detail": "公开牌槽保留卡面、报价、目标和余波；玩家在右侧详情中做竞猜，不在地图表面堆文字。",
				"why": "单击牌槽选中竞猜；双击打开卡牌详情。",
				"requirements": [{"text": "当前"}, {"text": "归属:匿名"}, {"text": "报价¥80"}],
				"actions": [{"id": "track_select_42", "label": "选中竞猜"}, {"id": "track_intel_42", "label": "线索档案"}, {"id": "track_open_orbital_finance_i", "label": "卡牌详情"}],
				"deep_links": [{"id": "track_intel_42", "label": "线索档案"}, {"id": "track_open_orbital_finance_i", "label": "卡牌详情"}],
				"select_action": "track_select_42",
				"open_action": "track_open_orbital_finance_i",
			},
			{"label": "公共事件", "slot": 2, "state": "queued", "kind": "event"},
		],
		"planet": {"title": "星球赌桌", "hint": "中央地图保留最大视觉中心"},
		"right_inspector": {
			"title": "当前说明",
			"why": "最近怪兽在本区，买牌可用。",
			"district": {
				"title": "雾港区",
				"summary": "海雾线升温｜牌架可看",
				"detail": "海雾线升温｜牌架可看",
				"full_detail": "海雾商品线正在升温。完整区域详情应进入抽屉，而不是常驻右侧主桌。这里还有供需、怪兽、牌架与历史线索。",
				"chips": [{"text": "怪兽邻近"}],
			},
			"requirements": [{"text": "怪兽半径 OK"}, {"text": "现金足够"}],
			"actions": [{"id": "buy", "label": "买牌"}],
			"deep_links": [{"id": "detail_region", "label": "区域详情"}],
		},
		"player_board": {
			"title": "玩家板｜测试手牌",
			"identity": "赤港财团",
			"cash_text": "¥ 1400",
			"gdp_text": "+24/s",
			"goal_text": "5000",
			"goal_ratio": 0.28,
			"quick_actions": [
				{"id": "build", "label": "建城", "state": "ready", "active": true},
				{"id": "rack", "label": "牌架", "state": "2张", "active": true},
				{"id": "buy", "label": "买牌", "state": "ready", "active": true},
				{"id": "play", "label": "出牌", "state": "waiting", "active": false},
			],
			"table_state_lamps": [
				{"text": "桌态", "state": "竞价", "active": true, "accent": Color("#f59e0b")},
				{"text": "本席", "state": "就绪", "active": true, "accent": Color("#38bdf8")},
			],
			"readiness_chips": [
				{"text": "选区就绪", "active": true, "accent": Color("#38bdf8")},
				{"text": "手牌 2/5", "active": false, "accent": Color("#c084fc")},
			],
			"selected_district_summary": "雾港区",
			"primary_action": "首召",
			"actions": [{"id": "summon", "label": "首召"}, {"id": "market", "label": "牌架"}],
			"hand_cards": [
				{"id": "test_hand_0", "name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "现金流上升；实时说明已更新。"},
				{"id": "test_hand_1", "name": "相位否决", "cost": "1", "type": "互动", "rank": "I", "effect": "反制直接互动牌。"},
			],
		},
	})
	await process_frame
	_expect(hand_rack != null and hand_rack.get_child_count() == 2 and first_hand_child_id == hand_rack.get_child(0).get_instance_id(), "split PlayerBoard does not rebuild identical hand cards during live-value refresh")
	var refreshed_first_card: Control = null
	if hand_rack != null and hand_rack.get_child_count() > 0:
		refreshed_first_card = hand_rack.get_child(0) as Control
	var refreshed_first_data: Dictionary = refreshed_first_card.call("get_card_data") if refreshed_first_card != null and refreshed_first_card.has_method("get_card_data") else {}
	_expect(refreshed_first_data.get("effect", "") == "现金流上升；实时说明已更新。", "split HandRack updates same-id card data without replacing the card node")
	var refreshed_hover_child_id := -1
	var refreshed_hover_scale := Vector2.ONE
	if hand_rack != null and hand_rack.has_method("get_hovered_card"):
		var refreshed_hover_variant: Variant = hand_rack.call("get_hovered_card")
		if refreshed_hover_variant is Control:
			var refreshed_hover := refreshed_hover_variant as Control
			refreshed_hover_child_id = refreshed_hover.get_instance_id()
			refreshed_hover_scale = refreshed_hover.scale
	_expect(hovered_hand_child_id > 0 and refreshed_hover_child_id == hovered_hand_child_id and refreshed_hover_scale.x > 1.0, "split HandRack preserves hovered hand-card lift through live-value refresh")
	_expect(player_quick_action_row != null and player_quick_action_row.get_child_count() == 4 and first_quick_action_id == player_quick_action_row.get_child(0).get_instance_id(), "split PlayerBoard does not rebuild identical quick action buttons during live-value refresh")
	_expect(player_status_lamp_row != null and player_status_lamp_row.get_child_count() == 1 and first_status_lamp_id == player_status_lamp_row.get_child(0).get_instance_id(), "split PlayerBoard does not rebuild identical table-state lamps during live-value refresh")
	_expect(player_readiness_chip_row != null and player_readiness_chip_row.get_child_count() == 1 and first_readiness_chip_id == player_readiness_chip_row.get_child(0).get_instance_id(), "split PlayerBoard does not rebuild identical readiness chips during live-value refresh")
	_expect(player_action_row != null and player_action_row.get_child_count() == 2 and first_primary_action_id == player_action_row.get_child(0).get_instance_id(), "split PlayerBoard does not rebuild identical primary action buttons during live-value refresh")
	_expect(requirement_row != null and requirement_row.get_child_count() == 2 and first_requirement_chip_id == requirement_row.get_child(0).get_instance_id(), "split RightInspector does not rebuild identical requirement chips during live-value refresh")
	_expect(district_chip_row != null and district_chip_row.get_child_count() == 1 and first_district_chip_id == district_chip_row.get_child(0).get_instance_id(), "split RightInspector does not rebuild identical district chips during live-value refresh")
	_expect(inspector_action_row != null and inspector_action_row.get_child_count() == 1 and first_inspector_action_id == inspector_action_row.get_child(0).get_instance_id(), "split RightInspector does not rebuild identical current-action buttons during live-value refresh")
	_expect(deep_link_row != null and deep_link_row.get_child_count() == 1 and first_deep_link_id == deep_link_row.get_child(0).get_instance_id(), "split RightInspector does not rebuild identical deep-link buttons during live-value refresh")
	var refreshed_public_track_slot := screen.find_child("PublicTrackSlot", true, false) as Control
	_expect(refreshed_public_track_slot != null and first_public_track_slot_id == refreshed_public_track_slot.get_instance_id(), "split PublicTrack does not rebuild identical anonymous offer slots during live-value refresh")
	_expect(map_host != null and not map_host.clip_contents, "split PlanetBoard keeps the runtime map uncut so space remains visible beyond the flat projection edge")
	var action_ids: Array[String] = []
	if screen.has_signal("action_requested"):
		screen.connect("action_requested", func(action_id: String) -> void:
			action_ids.append(action_id)
		)
	if menu_button != null:
		menu_button.emit_signal("pressed")
		await process_frame
		_expect(action_ids.has("menu"), "split TopBar menu button emits a menu action through GameScreen")
	if deep_link_row != null and deep_link_row.get_child_count() > 0 and deep_link_row.get_child(0) is Button:
		(deep_link_row.get_child(0) as Button).emit_signal("pressed")
		await process_frame
		_expect(side_drawer_panel != null and side_drawer_panel.visible, "split RightInspector detail links open the OverlayLayer side drawer")
		_expect(side_drawer_summary != null and side_drawer_summary.text.strip_edges() != "", "split OverlayLayer side drawer receives inspector detail text")
		_expect(side_drawer_summary != null and side_drawer_summary.text.contains("完整区域详情应进入抽屉"), "split OverlayLayer side drawer receives full 30-second region detail instead of only the table summary")
		var side_drawer_sections := screen.find_children("SideDrawerSectionCard*", "", true, false)
		_expect(side_drawer_sections.size() >= 3, "split OverlayLayer side drawer renders 30-second detail as section cards instead of one dense paragraph")
		_expect(_node_tree_text(side_drawer_section_list).contains("完整详情") and _node_tree_text(side_drawer_section_list).contains("完整区域详情应进入抽屉"), "split OverlayLayer section list keeps full detail in the drawer section body")
		_expect(action_ids.has("detail_region") and not action_ids.has("codex_region"), "split RightInspector detail link opens drawer before Codex")
		_expect(side_drawer_action_row != null and side_drawer_action_row.get_child_count() > 0 and side_drawer_action_row.get_child(0) is Button, "split OverlayLayer side drawer renders Codex follow-up actions as buttons")
		if side_drawer_action_row != null and side_drawer_action_row.get_child_count() > 0 and side_drawer_action_row.get_child(0) is Button:
			(side_drawer_action_row.get_child(0) as Button).emit_signal("pressed")
			await process_frame
			_expect(action_ids.has("codex_region"), "split OverlayLayer side drawer forwards Codex follow-up actions")
	_expect(public_track != null and public_track.has_signal("track_entry_selected") and public_track.has_signal("track_entry_opened"), "split PublicTrack exposes table-slot select/open signals")
	if refreshed_public_track_slot != null:
		var track_click := InputEventMouseButton.new()
		track_click.button_index = MOUSE_BUTTON_LEFT
		track_click.pressed = true
		refreshed_public_track_slot.gui_input.emit(track_click)
		await process_frame
		var track_inspector_text := _node_tree_text(right_inspector)
		_expect(action_ids.has("track_select_42"), "single-clicking a split PublicTrack slot emits its select action")
		_expect(track_inspector_text.contains("牌轨详情") and track_inspector_text.contains("轨道融资") and track_inspector_text.contains("选中竞猜") and track_inspector_text.contains("线索档案"), "single-clicking a split PublicTrack slot routes track detail and dossier action into RightInspector")
		var track_double_click := InputEventMouseButton.new()
		track_double_click.button_index = MOUSE_BUTTON_LEFT
		track_double_click.pressed = true
		track_double_click.double_click = true
		refreshed_public_track_slot.gui_input.emit(track_double_click)
		await process_frame
		_expect(action_ids.has("track_open_orbital_finance_i"), "double-clicking a split PublicTrack slot emits its card-detail open action")
	root.remove_child(screen)
	screen.queue_free()


func _check_core_layout_no_overlap() -> void:
	await _check_core_layout_for_scene("res://scenes/GameScreen.tscn", {
		"vertical": ["TopBar", "TableRow", "PlayerPanel"],
		"horizontal": ["LeftInfoPanel", "CenterTablePanel", "RightInfoPanel"],
	})
	await _check_core_layout_for_scene("res://scenes/ui/GameScreen.tscn", {
		"vertical": ["TopBar", "PublicTrack", "TableArea", "PlayerBoard"],
		"horizontal": ["PlanetBoard", "RightInspector"],
	})


func _check_core_layout_for_scene(path: String, groups: Dictionary) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s loads for overlap checks" % path)
	if packed == null:
		return
	for viewport_size in VIEWPORT_SIZES:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		root.add_child(viewport)
		var screen := packed.instantiate() as Control
		_expect(screen != null, "%s root is Control for %.0fx%.0f overlap check" % [path, viewport_size.x, viewport_size.y])
		if screen == null:
			root.remove_child(viewport)
			viewport.queue_free()
			continue
		viewport.add_child(screen)
		await process_frame
		await process_frame
		var vertical_names: Array = groups.get("vertical", [])
		_check_named_controls_do_not_overlap(screen, vertical_names, path, viewport_size)
		var horizontal_names: Array = groups.get("horizontal", [])
		_check_named_controls_do_not_overlap(screen, horizontal_names, path, viewport_size)
		viewport.remove_child(screen)
		screen.queue_free()
		root.remove_child(viewport)
		viewport.queue_free()


func _check_map_view_projection_defaults() -> void:
	var map_script := load("res://scripts/map_view.gd") as Script
	_expect(map_script != null, "MapView script loads for planet projection regression checks")
	if map_script == null:
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 720)
	root.add_child(viewport)
	var map_view := map_script.new() as Control
	_expect(map_view != null, "MapView instantiates for globe/local projection checks")
	if map_view == null:
		root.remove_child(viewport)
		viewport.queue_free()
		return
	map_view.size = Vector2(720, 720)
	viewport.add_child(map_view)
	await process_frame
	if map_view.has_method("set_map"):
		map_view.call("set_map", _map_view_projection_test_districts(), 1400.0, 950.0, 0, [
			Color("#0ea5e9"),
			Color("#22c55e"),
			Color("#f59e0b"),
			Color("#a855f7"),
		])
	await process_frame
	var default_snapshot: Dictionary = _map_projection_snapshot(map_view)
	_expect(float(default_snapshot.get("globe_blend", 0.0)) >= 0.95 and bool(default_snapshot.get("globe_mode", false)) and str(default_snapshot.get("mode", "")) == "globe", "MapView defaults to globe overview instead of flat/local color-block projection")
	_expect(absf(float(default_snapshot.get("view_zoom", 0.0)) - float(default_snapshot.get("globe_zoom", 1.0))) <= 0.002 and absf(float(default_snapshot.get("target_view_zoom", 0.0)) - float(default_snapshot.get("globe_zoom", 1.0))) <= 0.002, "MapView default view and target zoom use PLANET_PROJECTION_GLOBE_ZOOM")
	_expect(not bool(default_snapshot.get("complex_polygon_fill_in_globe", true)), "MapView globe overview avoids complex filled polygons that can become giant color blocks")
	for _i in range(12):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		map_view.call("_gui_input", wheel)
	for _frame in range(36):
		await process_frame
	var local_snapshot: Dictionary = _map_projection_snapshot(map_view)
	_expect(str(local_snapshot.get("mode", "")) == "local" or float(local_snapshot.get("globe_blend", 1.0)) <= 0.05, "MapView mouse wheel can still zoom from globe overview into local projection")
	if map_view.has_method("reset_to_planet_overview"):
		map_view.call("reset_to_planet_overview")
	await process_frame
	var returned_snapshot: Dictionary = _map_projection_snapshot(map_view)
	_expect(float(returned_snapshot.get("globe_blend", 0.0)) >= 0.95 and str(returned_snapshot.get("mode", "")) == "globe", "MapView can return from local zoom to the default globe overview")
	viewport.remove_child(map_view)
	map_view.queue_free()
	root.remove_child(viewport)
	viewport.queue_free()


func _map_projection_snapshot(map_view: Node) -> Dictionary:
	if map_view != null and map_view.has_method("get_projection_debug_snapshot"):
		var snapshot_variant: Variant = map_view.call("get_projection_debug_snapshot")
		return snapshot_variant if snapshot_variant is Dictionary else {}
	return {}


func _map_view_projection_test_districts() -> Array:
	return [
		{
			"name": "寒冠洋",
			"terrain": "ocean",
			"center": Vector2(360, 260),
			"radius_m": 84.0,
			"hp": 18,
			"products": ["ice"],
			"polygon": [Vector2(210, 160), Vector2(520, 180), Vector2(500, 340), Vector2(240, 360)],
		},
		{
			"name": "雾港城",
			"terrain": "land",
			"center": Vector2(760, 310),
			"radius_m": 78.0,
			"hp": 20,
			"products": ["ore"],
			"polygon": [Vector2(620, 220), Vector2(890, 210), Vector2(930, 390), Vector2(650, 420)],
		},
		{
			"name": "商路中继",
			"terrain": "ocean",
			"center": Vector2(520, 610),
			"radius_m": 68.0,
			"hp": 16,
			"products": ["water"],
			"polygon": [Vector2(360, 500), Vector2(620, 500), Vector2(640, 700), Vector2(390, 720)],
		},
		{
			"name": "试玩罗盘",
			"terrain": "land",
			"center": Vector2(930, 650),
			"radius_m": 92.0,
			"hp": 22,
			"products": ["crystal"],
			"polygon": [Vector2(760, 500), Vector2(1110, 520), Vector2(1080, 780), Vector2(790, 760)],
		},
	]


func _check_named_controls_do_not_overlap(screen: Control, names: Array, path: String, viewport_size: Vector2) -> void:
	for i in range(names.size()):
		var first := screen.find_child(str(names[i]), true, false) as Control
		_expect(first != null, "%s contains %s for %.0fx%.0f overlap check" % [path, str(names[i]), viewport_size.x, viewport_size.y])
		if first == null:
			continue
		for j in range(i + 1, names.size()):
			var second := screen.find_child(str(names[j]), true, false) as Control
			_expect(second != null, "%s contains %s for %.0fx%.0f overlap check" % [path, str(names[j]), viewport_size.x, viewport_size.y])
			if second == null:
				continue
			_expect(not _controls_visibly_overlap(first, second), "%s keeps %s and %s non-overlapping at %.0fx%.0f" % [path, first.name, second.name, viewport_size.x, viewport_size.y])


func _controls_visibly_overlap(first: Control, second: Control) -> bool:
	if not first.visible or not second.visible:
		return false
	var a := first.get_global_rect()
	var b := second.get_global_rect()
	return a.position.x < b.end.x - 1.0 and a.end.x > b.position.x + 1.0 and a.position.y < b.end.y - 1.0 and a.end.y > b.position.y + 1.0


func _check_named_controls_inside_viewport(screen: Control, names: Array, path: String, viewport_size: Vector2) -> void:
	for name_variant in names:
		var control := screen.find_child(str(name_variant), true, false) as Control
		_expect(control != null, "%s contains %s for viewport-fit check" % [path, str(name_variant)])
		if control == null or not control.visible:
			continue
		var rect := control.get_global_rect()
		_expect(rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0, "%s keeps %s fully inside %.0fx%.0f (rect %s)" % [path, control.name, viewport_size.x, viewport_size.y, str(rect)])


func _check_visible_buttons_inside_viewport(node: Node, path: String, viewport_size: Vector2) -> void:
	if node is Button and (node as Button).is_visible_in_tree():
		var button := node as Button
		var rect := button.get_global_rect()
		_expect(rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0, "%s keeps visible button %s inside %.0fx%.0f" % [path, button.name, viewport_size.x, viewport_size.y])
	for child in node.get_children():
		_check_visible_buttons_inside_viewport(child, path, viewport_size)


func _check_planet_is_largest_runtime_surface(screen: Control, path: String) -> void:
	var planet := screen.find_child("PlanetBoard", true, false) as Control
	var right := screen.find_child("RightInspector", true, false) as Control
	var player := screen.find_child("PlayerBoard", true, false) as Control
	_expect(planet != null and right != null and player != null, "%s has planet, inspector, and player board for visual-priority check" % path)
	if planet == null or right == null or player == null:
		return
	var planet_area := planet.get_global_rect().size.x * planet.get_global_rect().size.y
	var right_area := right.get_global_rect().size.x * right.get_global_rect().size.y
	var player_area := player.get_global_rect().size.x * player.get_global_rect().size.y
	_expect(planet_area > right_area and planet_area > player_area, "%s keeps PlanetBoard as the largest visible table surface" % path)


func _check_right_inspector_collapses_empty_panels(screen: Control, path: String) -> void:
	var reason_panel := screen.find_child("InspectorReasonPanel", true, false) as Control
	var reason_label := screen.find_child("InspectorReasonLabel", true, false) as Label
	var requirement_row := screen.find_child("InspectorRequirementChipRow", true, false)
	var event_log_panel := screen.find_child("EventLogPanel", true, false) as Control
	var event_log_label := screen.find_child("EventLogLabel", true, false) as Label
	_expect(reason_panel != null and event_log_panel != null, "%s exposes collapsible RightInspector reason/log panels" % path)
	if reason_panel != null and reason_panel.visible:
		var has_reason_text := reason_label != null and reason_label.text.strip_edges() != ""
		var requirement_text := _node_tree_text(requirement_row).strip_edges() if requirement_row != null else ""
		var has_requirement_chips := requirement_text != "" and not (requirement_text in ["条件", "暂无条件", "待选择"])
		_expect(has_reason_text or has_requirement_chips, "%s shows the RightInspector reason panel only when it has why text or requirement chips" % path)
		_expect(reason_label != null and reason_label.get_global_rect().size.y >= 18.0, "%s gives visible RightInspector reason text enough height to avoid blank-looking panels" % path)
	if event_log_panel != null and event_log_panel.visible:
		_expect(event_log_label != null and event_log_label.text.strip_edges() != "" and not event_log_label.text.contains("暂无公开事件"), "%s shows the RightInspector log panel only for real public log lines" % path)
		_expect(event_log_label != null and event_log_label.get_global_rect().size.y >= 28.0, "%s gives visible RightInspector log text enough height to avoid blank-looking panels" % path)


func _check_planet_board_square_stage_priority(screen: Control) -> void:
	var stage := screen.find_child("PlanetStageViewport", true, false) as Control
	var map_host := screen.find_child("MapHost", true, false) as Control
	var left_rail := screen.find_child("PlanetLeftSpaceRail", true, false) as Control
	var right_rail := screen.find_child("PlanetRightSpaceRail", true, false) as Control
	_expect(stage != null and map_host != null and left_rail != null and right_rail != null, "runtime PlanetBoard exposes square map host and side space rails")
	if stage == null or map_host == null or left_rail == null or right_rail == null:
		return
	var stage_rect := stage.get_global_rect()
	var map_rect := map_host.get_global_rect()
	_expect(absf(map_rect.size.x - map_rect.size.y) <= 1.5, "runtime MapHost stays square so the planet board reads as a board-game surface")
	_expect(map_rect.size.x <= stage_rect.size.y + 1.5, "runtime MapHost square is governed by available height instead of stretching into a wide strip")
	_expect(map_rect.size.y >= stage_rect.size.y - 2.0, "runtime MapHost claims the full square stage height before side rails receive leftover space")
	if stage_rect.size.x - map_rect.size.x > 210.0:
		_expect(left_rail.visible and right_rail.visible, "runtime PlanetBoard uses the extra left/right stage width as space rails instead of blank gutters")
		_expect(left_rail.get_global_rect().size.x >= 120.0 and right_rail.get_global_rect().size.x >= 120.0, "runtime PlanetBoard side rails are wide enough to make leftover space useful")
		_expect(left_rail.get_global_rect().size.y <= map_rect.size.y * 0.62 and right_rail.get_global_rect().size.y <= map_rect.size.y * 0.62, "runtime PlanetBoard keeps side rails tall enough to use side space while leaving visible outer space around the square")
		_expect(absf(left_rail.get_global_rect().end.x - map_rect.position.x) <= 16.0 and absf(right_rail.get_global_rect().position.x - map_rect.end.x) <= 16.0, "runtime PlanetBoard tucks compact side rails against the square planet instead of leaving empty gutters between them")
		var left_entries := left_rail.find_children("PlanetLeftRailEntry*", "", true, false)
		var right_entries := right_rail.find_children("PlanetRightRailEntry*", "", true, false)
		_expect(left_entries.size() >= 3 and right_entries.size() >= 3, "runtime PlanetBoard side rails render snapshot-backed public intelligence chips")
		_expect(_node_tree_text(left_rail).contains("星区") and _node_tree_text(left_rail).contains("牌架"), "runtime PlanetBoard left rail shows public surface intelligence instead of static filler")
		_expect(_node_tree_text(right_rail).contains("怪兽") and _node_tree_text(right_rail).contains("牌轨"), "runtime PlanetBoard right rail shows outer pressure and public-track state instead of static filler")


func _check_public_track_thin(screen: Control, path: String) -> void:
	var track := screen.find_child("PublicTrack", true, false) as Control
	_expect(track != null, "%s contains PublicTrack for anonymous offer rail check" % path)
	if track == null:
		return
	var slot := track.find_child("PublicTrackSlot", true, false) as Control
	var pip := track.find_child("PublicTrackStatePip", true, false) as ColorRect
	var card_face := track.find_child("CardFace", true, false)
	_expect(track.custom_minimum_size.y <= 48.0 and track.get_combined_minimum_size().y <= 52.0, "%s keeps PublicTrack as a thin top rail" % path)
	_expect(slot != null and slot.custom_minimum_size.y <= 36.0, "%s renders compact PublicTrack slots" % path)
	_expect(pip != null, "%s renders PublicTrack state pips for scan-first status" % path)
	_expect(card_face == null, "%s keeps full CardFace nodes out of the anonymous public track" % path)


func _check_player_board_first_glance_actions(screen: Control) -> void:
	var dock := screen.find_child("PlayerMainActionDock", true, false)
	_expect(dock != null, "runtime PlayerBoard exposes one main action dock for build/rack/buy/play")
	if dock == null:
		return
	var text := " ".join(_visible_text_under(dock))
	for keyword in ["建城", "牌架", "买牌", "出牌"]:
		_expect(text.contains(keyword), "runtime PlayerBoard main action dock shows %s at first glance" % keyword)
	for shortcut in ["1", "2", "3", "4"]:
		_expect(text.contains(shortcut), "runtime PlayerBoard main action dock shows keyboard shortcut %s at first glance" % shortcut)
	var shortcut_buttons := dock.find_children("*", "Button", true, false)
	var shortcuts := []
	for button_variant in shortcut_buttons:
		var button := button_variant as Button
		if button != null and button.has_meta("quick_action_shortcut"):
			shortcuts.append(str(button.get_meta("quick_action_shortcut", "")))
	_expect(shortcuts.has("1") and shortcuts.has("2") and shortcuts.has("3") and shortcuts.has("4"), "runtime ActionDock stores data-backed quick-action shortcuts for tests and accessibility")


func _check_player_board_hand_rack_priority(screen: Control) -> void:
	var hand_rack := screen.find_child("HandRack", true, false) as Control
	var dock := screen.find_child("PlayerMainActionDock", true, false) as Control
	var resource_tableau := screen.find_child("PlayerResourceTableau", true, false) as Control
	var hand_tableau := screen.find_child("PlayerHandTableau", true, false) as Control
	var command_tableau := screen.find_child("PlayerCommandTableau", true, false) as Control
	_expect(hand_rack != null and dock != null, "runtime PlayerBoard keeps both hand rack and compact action dock")
	if hand_rack == null or dock == null:
		return
	var hand_rect := hand_rack.get_global_rect()
	var dock_rect := dock.get_global_rect()
	_expect(hand_rect.size.y >= 78.0, "runtime HandRack keeps enough visible height for table-edge cards")
	_expect(hand_rect.size.x > dock_rect.size.x, "runtime HandRack keeps wider table-edge space than the action dock")
	_expect(dock_rect.size.x <= 300.0, "runtime PlayerMainActionDock stays compact so hand cards own the bottom rail")
	_expect(resource_tableau != null and hand_tableau != null and command_tableau != null, "runtime PlayerBoard uses resource, hand, and command tableaus")
	if resource_tableau != null and hand_tableau != null and command_tableau != null:
		var resource_rect := resource_tableau.get_global_rect()
		var hand_tableau_rect := hand_tableau.get_global_rect()
		var command_rect := command_tableau.get_global_rect()
		_expect(resource_rect.position.x < hand_tableau_rect.position.x and hand_tableau_rect.position.x < command_rect.position.x, "runtime PlayerBoard orders tableaus as resources, hand, then command")
		_expect(hand_tableau_rect.size.x > resource_rect.size.x and hand_tableau_rect.size.x > command_rect.size.x, "runtime PlayerBoard keeps the hand tableau as the widest bottom-table area")


func _check_main_table_text_is_scan_first(screen: Control, path: String) -> void:
	var banned_terms := ["debug", "todo", "调试", "开发", "完整规则", "规则说明", "复盘", "测试报告"]
	for entry in _visible_text_entries(screen):
		var text := str(entry.get("text", "")).replace("\n", " ").strip_edges()
		if text == "":
			continue
		var lower := text.to_lower()
		_expect(text.length() <= 220, "%s keeps visible text scan-first instead of long rules/dev prose: %s" % [path, _short_test_text(text, 48)])
		for term in banned_terms:
			_expect(not lower.contains(str(term).to_lower()), "%s keeps 3-minute/dev term off the main table: %s" % [path, term])


func _visible_text_under(node: Node) -> Array[String]:
	var result: Array[String] = []
	for entry in _visible_text_entries(node):
		result.append(str(entry.get("text", "")))
	return result


func _visible_text_entries(node: Node) -> Array:
	var result: Array = []
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return result
	var text := _node_display_text(node)
	if text.strip_edges() != "":
		result.append({"node": node.name, "text": text})
	for child in node.get_children():
		result.append_array(_visible_text_entries(child))
	return result


func _node_display_text(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	if node is RichTextLabel:
		return (node as RichTextLabel).text
	return ""


func _short_test_text(value: String, max_chars: int) -> String:
	var clean := value.replace("\n", " ").strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s..." % clean.substr(0, maxi(0, max_chars - 3))


func _action_list_has_id(actions: Array, action_id: String) -> bool:
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("id", "")) == action_id:
			return true
	return false


func _array_has_prefix(values: Array, prefix: String) -> bool:
	for value_variant in values:
		if str(value_variant).begins_with(prefix):
			return true
	return false


func _action_list_has_label(actions: Array, expected_label: String) -> bool:
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		for key in ["label", "title", "text"]:
			if str(action.get(key, "")).contains(expected_label):
				return true
	return false


func _variant_contains_callable(value: Variant) -> bool:
	if value is Callable:
		return true
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key in dictionary.keys():
			if _variant_contains_callable(key) or _variant_contains_callable(dictionary[key]):
				return true
	elif value is Array:
		var array: Array = value
		for item in array:
			if _variant_contains_callable(item):
				return true
	return false


func _check_runtime_map_mouse_selection_flow(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime map mouse flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		if main.has_method("_close_menu"):
			main.call("_close_menu")
			await process_frame
	var map_view := main.get("map_view") as Control
	var map_host := runtime_screen.find_child("MapHost", true, false) as Control
	_expect(map_view != null and map_host != null and map_view.get_parent() == map_host, "runtime map mouse flow uses the live MapView mounted in split MapHost")
	if map_view == null or map_host == null:
		return
	_expect(map_view.has_method("get_district_control_position"), "runtime MapView exposes district control coordinates for real input routing")
	if not map_view.has_method("get_district_control_position"):
		return
	var current_district := int(main.get("selected_district"))
	var target_district := _first_runtime_alive_district_with_supply(main, current_district)
	if target_district < 0:
		target_district = _first_runtime_alive_district_except(main, current_district)
	_expect(target_district >= 0, "runtime map mouse flow finds a live target district")
	if target_district < 0:
		return
	var previous_district := _first_runtime_alive_district_except(main, target_district)
	if previous_district >= 0:
		main.set("selected_district", previous_district)
	_force_runtime_screen_sync(main)
	await process_frame
	var position_variant: Variant = map_view.call("get_district_control_position", target_district)
	var local_position: Vector2 = position_variant if position_variant is Vector2 else Vector2(-1.0, -1.0)
	_expect(local_position.x >= 0.0 and local_position.y >= 0.0 and local_position.x <= map_view.size.x and local_position.y <= map_view.size.y, "runtime MapView returns an on-board input point for the target district")
	if local_position.x < 0.0 or local_position.y < 0.0:
		return
	_click_map_control(map_view, local_position, false)
	await process_frame
	await process_frame
	_expect(int(main.get("selected_district")) == target_district, "single-clicking the live MapView selects the target district through real mouse release")
	var snapshot_variant: Variant = main.call("_runtime_table_snapshot") if main.has_method("_runtime_table_snapshot") else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var top_bar: Dictionary = snapshot.get("top_bar", {}) if snapshot.get("top_bar", {}) is Dictionary else {}
	var districts := _runtime_districts(main)
	var district_name := ""
	if target_district >= 0 and target_district < districts.size() and districts[target_district] is Dictionary:
		district_name = String((districts[target_district] as Dictionary).get("name", ""))
	_expect(district_name == "" or str(top_bar.get("selected_district", "")).contains(district_name), "MapView click refreshes the split top-bar selected-region label")
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	_click_map_control(map_view, local_position, true)
	await process_frame
	await process_frame
	var supply_overlay := main.get("district_supply_overlay") as Control
	_expect(supply_overlay != null and supply_overlay.visible and int(main.get("district_supply_open_district")) == target_district, "double-clicking the live MapView opens the matching district supply drawer")


func _check_runtime_main_action_dock_click_flow(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime quick-action click flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	var dock := runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
	_expect(dock != null, "runtime quick-action click flow finds the live PlayerMainActionDock")
	if dock == null:
		return

	var supply_district := _first_runtime_district_with_supply(main)
	_expect(supply_district >= 0, "runtime quick-action click flow finds a district with public card supply")
	if supply_district >= 0:
		main.set("selected_district", supply_district)
		_force_runtime_screen_sync(main)
		await process_frame
		dock = runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
		var rack_button := _find_enabled_visible_button_containing(dock, "牌架")
		_expect(rack_button != null and not rack_button.disabled, "runtime PlayerMainActionDock renders an enabled Rack quick button for a supplied district")
		if rack_button != null and not rack_button.disabled:
			rack_button.emit_signal("pressed")
			await process_frame
			await process_frame
			var supply_overlay := main.get("district_supply_overlay") as Control
			_expect(supply_overlay != null and supply_overlay.visible, "clicking the live Rack quick button opens the district supply drawer")
			_expect(int(main.get("district_supply_open_district")) == supply_district, "clicking the live Rack quick button opens supply for the selected district")
		if main.has_method("_close_district_supply_overlay"):
			main.call("_close_district_supply_overlay")
			await process_frame

	var build_district := _first_runtime_buildable_district(main)
	_expect(build_district >= 0, "runtime quick-action click flow finds a legal city-build district")
	if build_district >= 0:
		main.set("selected_district", build_district)
		_force_runtime_screen_sync(main)
		await process_frame
		dock = runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
		var build_button := _find_enabled_visible_button_containing(dock, "建城")
		var cities_before := _runtime_active_city_count(main)
		_expect(build_button != null and not build_button.disabled, "runtime PlayerMainActionDock renders an enabled Build quick button for a legal city district")
		if build_button != null and not build_button.disabled:
			build_button.emit_signal("pressed")
			await process_frame
			await process_frame
			var built_city := _runtime_district_city(main, build_district)
			_expect(_runtime_active_city_count(main) == cities_before + 1 and not built_city.is_empty() and int(built_city.get("owner", -1)) == 0, "clicking the live Build quick button creates a player city through the gameplay controller")

	var action_context := _first_runtime_actionable_hand_context(main)
	var actionable_slot := int(action_context.get("slot", -1))
	if not action_context.is_empty():
		main.set("selected_district", int(action_context.get("district", -1)))
	_clear_runtime_player_action_cooldown(main, 0)
	_force_runtime_screen_sync(main)
	await process_frame
	dock = runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
	var play_button := _find_enabled_visible_button_containing(dock, "出牌")
	var queue_before := _runtime_card_resolution_entry_count(main)
	_expect(actionable_slot >= 0 and play_button != null and not play_button.disabled, "runtime PlayerMainActionDock renders an enabled Play quick button when a hand card is actionable")
	if actionable_slot >= 0 and play_button != null and not play_button.disabled:
		play_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_expect(_runtime_card_resolution_entry_count(main) > queue_before, "clicking the live Play quick button commits an anonymous card to the public resolution track")
		await _resolve_runtime_card_resolution_until_idle(main)
		_expect(_runtime_owned_monster_count(main, 0) > 0, "clicking the live Play quick button can complete the first summon through the public resolution track")

	var buy_offer := _first_runtime_direct_buy_offer(main)
	_expect(not buy_offer.is_empty(), "runtime quick-action click flow finds a directly purchasable district supply card after first summon")
	if not buy_offer.is_empty():
		var buy_district := int(buy_offer.get("district", -1))
		var buy_card := String(buy_offer.get("card", ""))
		main.set("selected_district", buy_district)
		main.set("selected_market_skill", buy_card)
		main.set("previewed_district_card", buy_card)
		_force_runtime_screen_sync(main)
		await process_frame
		dock = runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
		var buy_quick_button := _find_enabled_visible_button_containing(dock, "买牌")
		_expect(buy_quick_button != null and not buy_quick_button.disabled, "runtime PlayerMainActionDock renders an enabled Buy quick button for a monster-accessible supply")
		if buy_quick_button != null and not buy_quick_button.disabled:
			var hand_before := _runtime_player_counted_hand_size(main, 0)
			var cash_before := _runtime_player_cash(main, 0)
			var had_family_before := _runtime_player_has_card_family(main, 0, buy_card)
			buy_quick_button.emit_signal("pressed")
			await process_frame
			await process_frame
			var buy_overlay := main.get("district_supply_overlay") as Control
			_expect(buy_overlay != null and buy_overlay.visible and int(main.get("district_supply_open_district")) == buy_district, "clicking the live Buy quick button opens the district supply drawer for the purchasable district")
			var preview_buy_button := buy_overlay.find_child("DistrictSupplyPreviewBuyButton", true, false) as Button if buy_overlay != null else null
			_expect(preview_buy_button != null and not preview_buy_button.disabled, "district supply drawer exposes an enabled preview Buy button for the selected card")
			if preview_buy_button != null and not preview_buy_button.disabled:
				preview_buy_button.emit_signal("pressed")
				await process_frame
				await process_frame
				var hand_after := _runtime_player_counted_hand_size(main, 0)
				var cash_after := _runtime_player_cash(main, 0)
				var has_family_after := _runtime_player_has_card_family(main, 0, buy_card)
				_expect(cash_after < cash_before, "clicking the drawer Buy button spends player cash through the gameplay controller")
				_expect((hand_after > hand_before) or (not had_family_before and has_family_after), "clicking the drawer Buy button adds the selected card family to the player's private hand")


func _check_runtime_hand_card_double_click_play(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime hand-card double-click flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		if main.has_method("_close_menu"):
			main.call("_close_menu")
			await process_frame
	var action_context := _first_runtime_actionable_hand_context(main)
	_expect(not action_context.is_empty(), "runtime hand-card double-click flow finds an actionable hand card and map context")
	if action_context.is_empty():
		return
	var district_index := int(action_context.get("district", -1))
	var slot_index := int(action_context.get("slot", -1))
	main.set("selected_district", district_index)
	main.set("selected_runtime_card_slot", -1)
	_force_runtime_screen_sync(main)
	await process_frame
	var hand_card := _runtime_hand_card_control(runtime_screen, slot_index)
	_expect(hand_card != null, "runtime HandRack renders the actionable card as a live CardFace")
	if hand_card == null:
		return
	var queue_before := _runtime_card_resolution_entry_count(main)
	_double_click_card_control(hand_card)
	await process_frame
	await process_frame
	_expect(int(main.get("selected_runtime_card_slot")) == slot_index, "double-clicking a live hand card selects the matching runtime hand slot")
	_expect(_runtime_card_resolution_entry_count(main) > queue_before, "double-clicking a live hand card commits it to the public resolution track through the gameplay controller")


func _check_runtime_hand_card_drag_to_map_play(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime hand-card drag-to-map flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		if main.has_method("_close_menu"):
			main.call("_close_menu")
			await process_frame
	var action_context := _first_runtime_actionable_hand_context(main)
	_expect(not action_context.is_empty(), "runtime hand-card drag-to-map flow finds an actionable hand card and map target")
	if action_context.is_empty():
		return
	var target_district := int(action_context.get("district", -1))
	var slot_index := int(action_context.get("slot", -1))
	var map_view := main.get("map_view") as Control
	_expect(map_view != null and map_view.has_method("get_district_control_position") and map_view.has_method("get_district_at_control_position"), "runtime hand-card drag-to-map flow uses MapView coordinate and hit-test helpers")
	if map_view == null or not map_view.has_method("get_district_control_position"):
		return
	if map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")
		await process_frame
	var previous_district := _first_runtime_alive_district_except(main, target_district)
	if previous_district >= 0:
		main.set("selected_district", previous_district)
	main.set("selected_runtime_card_slot", -1)
	_force_runtime_screen_sync(main)
	await process_frame
	var hand_card := _runtime_hand_card_control(runtime_screen, slot_index)
	_expect(hand_card != null, "runtime HandRack renders the draggable card as a live CardFace")
	if hand_card == null:
		return
	var local_position_variant: Variant = map_view.call("get_district_control_position", target_district)
	var local_position: Vector2 = local_position_variant if local_position_variant is Vector2 else Vector2(-1.0, -1.0)
	_expect(local_position.x >= 0.0 and local_position.y >= 0.0, "runtime hand-card drag-to-map flow resolves a visible target district drop point")
	if local_position.x < 0.0 or local_position.y < 0.0:
		return
	var drop_screen_position := map_view.get_global_rect().position + local_position
	var queue_before := _runtime_card_resolution_entry_count(main)
	_drag_card_control_to_screen(hand_card, drop_screen_position)
	await process_frame
	await process_frame
	_expect(int(main.get("selected_district")) == target_district, "dragging a live hand card onto a map district selects the drop district before playing")
	_expect(int(main.get("selected_runtime_card_slot")) == slot_index, "dragging a live hand card onto the map selects the matching runtime hand slot")
	_expect(_runtime_card_resolution_entry_count(main) > queue_before, "dragging a live hand card onto the map commits it to the public resolution track through the gameplay controller")
	main.set("selected_card_resolution_id", -1)
	_force_runtime_screen_sync(main)
	await process_frame
	var track_action_ids: Array[String] = []
	if runtime_screen.has_signal("action_requested"):
		runtime_screen.connect("action_requested", func(action_id: String) -> void:
			track_action_ids.append(action_id)
		)
	var track_slot := runtime_screen.find_child("PublicTrackSlot", true, false) as Control
	_expect(track_slot != null, "runtime PublicTrack renders the newly queued anonymous card as a clickable table slot")
	if track_slot == null:
		return
	var track_click := InputEventMouseButton.new()
	track_click.button_index = MOUSE_BUTTON_LEFT
	track_click.pressed = true
	track_slot.gui_input.emit(track_click)
	await process_frame
	await process_frame
	var selected_resolution_id := int(main.get("selected_card_resolution_id"))
	var runtime_right_inspector := runtime_screen.find_child("RightInspector", true, false)
	var runtime_inspector_text := _node_tree_text(runtime_right_inspector)
	_expect(selected_resolution_id >= 0, "single-clicking a runtime PublicTrack slot selects a card-resolution guess target in main")
	_expect(_array_has_prefix(track_action_ids, "track_select_"), "single-clicking a runtime PublicTrack slot emits a track_select action through GameScreen")
	_expect(runtime_inspector_text.contains("牌轨详情") and runtime_inspector_text.contains("选中竞猜") and runtime_inspector_text.contains("线索档案"), "runtime PublicTrack click keeps the selected track detail and dossier action in RightInspector after main resync")
	var intel_button := _find_visible_button_containing(runtime_right_inspector, "线索档案")
	_expect(intel_button != null, "runtime selected PublicTrack detail exposes a direct intel dossier action")
	if intel_button != null:
		intel_button.emit_signal("pressed")
		await process_frame
		await process_frame
		var menu_title_label := main.get("menu_title_label") as Label
		var menu_preview_box := main.get("menu_preview_box") as VBoxContainer
		var dossier_text := _node_tree_text(menu_preview_box)
		_expect(track_action_ids.has("track_intel_%d" % selected_resolution_id), "pressing the runtime track dossier action emits the focused track_intel command")
		_expect(menu_title_label != null and menu_title_label.text == "情报档案" and dossier_text.contains("已选牌轨") and dossier_text.contains("查看卡牌线索") and dossier_text.contains("已选牌轨证据链") and dossier_text.contains("出价记录") and dossier_text.contains("余波线索") and dossier_text.contains("私人推理") and dossier_text.contains("回到牌轨") and dossier_text.contains("竞猜") and dossier_text.contains("卡牌详情"), "runtime track dossier action opens the intel dossier with the selected public-track evidence chain focused and track/guess/detail paths")
		var dossier_guess_button := _find_visible_button_containing(menu_preview_box, "竞猜")
		_expect(dossier_guess_button != null, "runtime focused IntelDossier exposes a guess path back to the selected public-track card")
		if dossier_guess_button != null:
			dossier_guess_button.emit_signal("pressed")
			await process_frame
			await process_frame
			var menu_overlay := main.get("menu_overlay") as Control
			_expect(menu_overlay != null and not menu_overlay.visible, "runtime IntelDossier guess path returns to the main table instead of resolving inside the dossier")
			_expect(int(main.get("selected_card_resolution_id")) == selected_resolution_id, "runtime IntelDossier guess path keeps the same selected public-track resolution_id")
			_force_runtime_screen_sync(main)
			await process_frame
			var selected_track_marker := runtime_screen.find_child("PublicTrackSlotSelected", true, false)
			var track_focus_label := runtime_screen.find_child("TrackFocusLabel", true, false) as Label
			_expect(selected_track_marker != null and track_focus_label != null and track_focus_label.text.contains("已选牌轨"), "runtime IntelDossier guess path returns to the same selected PublicTrack focus")


func _check_runtime_blocked_hand_card_drag_reason(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime blocked hand-card drag flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		if main.has_method("_close_menu"):
			main.call("_close_menu")
			await process_frame
	var action_context := _first_runtime_actionable_hand_context(main)
	_expect(not action_context.is_empty(), "runtime blocked hand-card drag flow can first find a playable card")
	if action_context.is_empty():
		return
	var target_district := int(action_context.get("district", -1))
	var slot_index := int(action_context.get("slot", -1))
	var map_view := main.get("map_view") as Control
	_expect(map_view != null and map_view.has_method("get_district_control_position"), "runtime blocked hand-card drag flow uses MapView drop coordinates")
	if map_view == null or not map_view.has_method("get_district_control_position"):
		return
	main.set("selected_district", target_district)
	_set_runtime_player_action_cooldown(main, 0, 2.5)
	main.set("selected_runtime_card_slot", -1)
	_force_runtime_screen_sync(main)
	await process_frame
	var hand_card := _runtime_hand_card_control(runtime_screen, slot_index)
	_expect(hand_card != null, "runtime blocked hand-card drag flow still renders the disabled CardFace")
	if hand_card == null:
		return
	var card_data_variant: Variant = hand_card.call("get_card_data") if hand_card.has_method("get_card_data") else {}
	var card_data: Dictionary = card_data_variant if card_data_variant is Dictionary else {}
	_expect(bool(card_data.get("drop_enabled", true)) == false and bool(card_data.get("actionable", true)) == false, "runtime blocked hand-card snapshot marks the CardFace as not droppable")
	_expect(str(card_data.get("block_reason", "")).contains("冷却") or str(card_data.get("drop_label", "")).contains("冷却"), "runtime blocked hand-card snapshot exposes the cooldown reason to drag feedback")
	var local_position_variant: Variant = map_view.call("get_district_control_position", target_district)
	var local_position: Vector2 = local_position_variant if local_position_variant is Vector2 else Vector2(-1.0, -1.0)
	if local_position.x < 0.0 or local_position.y < 0.0:
		return
	var queue_before := _runtime_card_resolution_entry_count(main)
	_drag_card_control_to_screen(hand_card, map_view.get_global_rect().position + local_position)
	await process_frame
	await process_frame
	_expect(_runtime_card_resolution_entry_count(main) == queue_before, "dragging a cooldown-blocked hand card onto the map does not enter the public resolution track")
	_clear_runtime_player_action_cooldown(main, 0)
	_force_runtime_screen_sync(main)


func _check_runtime_market_card_double_click_purchase(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime market-card double-click flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		if main.has_method("_close_menu"):
			main.call("_close_menu")
			await process_frame
	var action_context := _first_runtime_actionable_hand_context(main)
	_expect(not action_context.is_empty(), "runtime market-card double-click flow can prepare first monster access")
	if action_context.is_empty():
		return
	main.set("selected_district", int(action_context.get("district", -1)))
	_force_runtime_screen_sync(main)
	await process_frame
	var dock := runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
	var play_button := _find_visible_button_containing(dock, "出牌")
	_expect(play_button != null and not play_button.disabled, "runtime market-card double-click setup finds a live Play quick button")
	if play_button == null or play_button.disabled:
		return
	play_button.emit_signal("pressed")
	await process_frame
	await process_frame
	await _resolve_runtime_card_resolution_until_idle(main)
	_expect(_runtime_owned_monster_count(main, 0) > 0, "runtime market-card double-click setup resolves first monster access")
	var buy_offer := _first_runtime_direct_buy_offer(main)
	_expect(not buy_offer.is_empty(), "runtime market-card double-click flow finds a directly purchasable market card")
	if buy_offer.is_empty():
		return
	var buy_district := int(buy_offer.get("district", -1))
	var buy_card := String(buy_offer.get("card", ""))
	main.set("selected_district", buy_district)
	main.set("selected_market_skill", buy_card)
	main.set("previewed_district_card", buy_card)
	_force_runtime_screen_sync(main)
	await process_frame
	dock = runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
	var buy_quick_button := _find_visible_button_containing(dock, "买牌")
	_expect(buy_quick_button != null and not buy_quick_button.disabled, "runtime market-card double-click flow opens a purchasable rack through the live Buy quick button")
	if buy_quick_button == null or buy_quick_button.disabled:
		return
	var hand_before := _runtime_player_counted_hand_size(main, 0)
	var cash_before := _runtime_player_cash(main, 0)
	var had_family_before := _runtime_player_has_card_family(main, 0, buy_card)
	buy_quick_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var buy_overlay := main.get("district_supply_overlay") as Control
	_expect(buy_overlay != null and buy_overlay.visible and int(main.get("district_supply_open_district")) == buy_district, "runtime market-card double-click flow opens the selected district supply drawer")
	var market_card := _runtime_district_supply_market_card_control(buy_overlay, buy_card)
	_expect(market_card != null, "runtime district supply drawer renders the target market card as a live double-clickable card")
	if market_card == null:
		return
	_double_click_card_control(market_card)
	await process_frame
	await process_frame
	var hand_after := _runtime_player_counted_hand_size(main, 0)
	var cash_after := _runtime_player_cash(main, 0)
	var has_family_after := _runtime_player_has_card_family(main, 0, buy_card)
	_expect(cash_after < cash_before, "double-clicking a live market card spends player cash through the gameplay controller")
	_expect((hand_after > hand_before) or (not had_family_before and has_family_after), "double-clicking a live market card adds the selected family to the player's private hand")


func _check_runtime_full_hand_private_discard_purchase(main: Node, runtime_screen: Control) -> void:
	_expect(runtime_screen != null, "runtime full-hand private discard flow has the live split GameScreen")
	if runtime_screen == null:
		return
	if main.has_method("_close_district_supply_overlay"):
		main.call("_close_district_supply_overlay")
		await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		if main.has_method("_close_menu"):
			main.call("_close_menu")
			await process_frame
	var district_index := _first_runtime_alive_district(main)
	_expect(district_index >= 0, "runtime full-hand private discard flow finds a live district")
	if district_index < 0:
		return
	var incoming_card := "城市融资1"
	var old_card := "移动1"
	_prepare_runtime_full_hand_purchase(main, district_index, incoming_card)
	_force_runtime_screen_sync(main)
	await process_frame
	var dock := runtime_screen.find_child("PlayerMainActionDock", true, false) as Control
	var buy_button := _find_visible_button_containing(dock, "买牌")
	_expect(buy_button != null and not buy_button.disabled, "runtime full-hand private discard flow exposes Buy as ready before the purchase")
	if buy_button == null or buy_button.disabled:
		return
	var hand_before := _runtime_player_counted_hand_size(main, 0)
	var cash_before := _runtime_player_cash(main, 0)
	var log_start := _runtime_public_log_count(main)
	buy_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var buy_overlay := main.get("district_supply_overlay") as Control
	var market_card := _runtime_district_supply_market_card_control(buy_overlay, incoming_card)
	_expect(market_card != null, "runtime full-hand private discard flow renders the target market card inside the live drawer")
	if market_card == null:
		return
	_double_click_card_control(market_card)
	await process_frame
	await process_frame
	var pending: Dictionary = main.get("pending_discard_purchase") if main.get("pending_discard_purchase") is Dictionary else {}
	_expect(not pending.is_empty() and String(pending.get("skill_name", "")) == incoming_card, "double-clicking a full-hand market card opens a pending private discard purchase")
	_force_runtime_screen_sync(main)
	await process_frame
	var decision_panel := runtime_screen.find_child("TemporaryDecisionModal", true, false) as Control
	var discard_button := _find_visible_button_containing(decision_panel, "弃掉")
	_expect(decision_panel != null and decision_panel.visible, "split OverlayLayer shows the private discard decision as a visible modal")
	_expect(_node_tree_text(decision_panel).contains("私密弃牌确认") and _node_tree_text(decision_panel).contains("不公开"), "private discard modal explains the privacy boundary before choosing")
	_expect(discard_button != null and not discard_button.disabled, "private discard modal renders an enabled discard button")
	if discard_button == null or discard_button.disabled:
		return
	discard_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var names_after := _runtime_player_card_names(main, 0)
	var pending_after: Dictionary = main.get("pending_discard_purchase") if main.get("pending_discard_purchase") is Dictionary else {}
	var decision_after := runtime_screen.find_child("TemporaryDecisionModal", true, false) as Control
	_expect(pending_after.is_empty(), "clicking the private discard button clears the pending discard purchase")
	_expect(_runtime_player_counted_hand_size(main, 0) == hand_before, "private discard purchase keeps the counted hand at the limit after replacing one old card")
	_expect(_runtime_player_cash(main, 0) < cash_before, "private discard purchase spends cash only after the discard choice resolves")
	_expect(names_after.has(incoming_card) and not names_after.has(old_card), "private discard purchase removes the chosen old card and adds the purchased card")
	_expect(decision_after == null or not decision_after.visible, "split private discard modal hides after the purchase resolves")
	_expect(not _runtime_public_log_slice_has_secret(main, log_start, [incoming_card, old_card, "弃掉"]), "private discard purchase does not leak card names or discard details into the public log")


func _force_runtime_screen_sync(main: Node) -> void:
	if main.has_method("_sync_runtime_game_screen"):
		main.call("_sync_runtime_game_screen", true)


func _resolve_runtime_card_resolution_until_idle(main: Node) -> void:
	if not main.has_method("_update_card_resolution_queue"):
		return
	for _i in range(8):
		if _runtime_card_resolution_entry_count(main) <= 0:
			return
		main.call("_update_card_resolution_queue", 99.0)
		_force_runtime_screen_sync(main)
		await process_frame


func _find_visible_button_containing(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return null
	if node is Button:
		var button := node as Button
		if button.text.contains(text):
			return button
	for child in node.get_children():
		var found := _find_visible_button_containing(child, text)
		if found != null:
			return found
	return null


func _find_enabled_visible_button_containing(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return null
	if node is Button:
		var button := node as Button
		if button.text.contains(text) and not button.disabled:
			return button
	for child in node.get_children():
		var found := _find_enabled_visible_button_containing(child, text)
		if found != null:
			return found
	return null


func _runtime_districts(main: Node) -> Array:
	var districts_variant: Variant = main.get("districts")
	return districts_variant if districts_variant is Array else []


func _first_runtime_district_with_supply(main: Node) -> int:
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if not (districts[i] is Dictionary):
			continue
		var district: Dictionary = districts[i]
		var choices_variant: Variant = district.get("card_choices", [])
		var choices: Array = choices_variant if choices_variant is Array else []
		if not bool(district.get("destroyed", false)) and not choices.is_empty():
			return i
	return -1


func _first_runtime_buildable_district(main: Node) -> int:
	if not main.has_method("_city_build_error_for"):
		return -1
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if String(main.call("_city_build_error_for", 0, i, false)) == "":
			return i
	return -1


func _first_runtime_actionable_hand_context(main: Node) -> Dictionary:
	if not main.has_method("_first_actionable_hand_slot"):
		return {}
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if not (districts[i] is Dictionary):
			continue
		var district: Dictionary = districts[i]
		if bool(district.get("destroyed", false)):
			continue
		main.set("selected_district", i)
		var slot_index := int(main.call("_first_actionable_hand_slot", 0))
		if slot_index >= 0:
			return {"district": i, "slot": slot_index}
	return {}


func _first_runtime_direct_buy_offer(main: Node) -> Dictionary:
	if not main.has_method("_can_buy_card_from_district") or not main.has_method("_district_supply_purchase_state"):
		return {}
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if not bool(main.call("_can_buy_card_from_district", i, 0)):
			continue
		if not (districts[i] is Dictionary):
			continue
		var district: Dictionary = districts[i]
		var choices_variant: Variant = district.get("card_choices", [])
		var choices: Array = choices_variant if choices_variant is Array else []
		for card_variant in choices:
			var card_name := String(card_variant)
			var state_variant: Variant = main.call("_district_supply_purchase_state", i, card_name, 0)
			var state: Dictionary = state_variant if state_variant is Dictionary else {}
			if bool(state.get("actionable", false)) and not bool(state.get("requires_discard", false)) and not _runtime_player_has_card_family(main, 0, card_name):
				return {"district": i, "card": card_name}
	return {}


func _prepare_runtime_full_hand_purchase(main: Node, district_index: int, incoming_card: String) -> void:
	var districts := _runtime_districts(main).duplicate(true)
	if district_index >= 0 and district_index < districts.size() and districts[district_index] is Dictionary:
		var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
		district["card_choices"] = [incoming_card]
		districts[district_index] = district
		main.set("districts", districts)
	if main.has_method("_make_auto_monster"):
		main.set("auto_monsters", [main.call("_make_auto_monster", 0, 0, district_index, 0, 1)])
	var players := _runtime_players(main).duplicate(true)
	if not players.is_empty() and players[0] is Dictionary:
		var player: Dictionary = (players[0] as Dictionary).duplicate(true)
		player["is_ai"] = false
		player["seat_type"] = "human"
		player["role_card"] = {}
		player["cash"] = 5000
		player["action_cooldown"] = 0.0
		player["economic_ledger"] = []
		if main.has_method("_make_skill"):
			player["slots"] = [
				main.call("_make_skill", "移动1"),
				main.call("_make_skill", "装甲再生1"),
				main.call("_make_skill", "舆论操控1"),
				main.call("_make_skill", "业主透镜1"),
				main.call("_make_skill", "区域供需合约1"),
			]
		players[0] = player
		main.set("players", players)
	main.set("selected_player", 0)
	main.set("inspected_player", 0)
	main.set("selected_district", district_index)
	main.set("selected_market_skill", incoming_card)
	main.set("previewed_district_card", incoming_card)
	main.set("pending_discard_purchase", {})


func _first_runtime_alive_district(main: Node) -> int:
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if not (districts[i] is Dictionary):
			continue
		var district: Dictionary = districts[i]
		if not bool(district.get("destroyed", false)):
			return i
	return -1


func _first_runtime_alive_district_except(main: Node, excluded_index: int) -> int:
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if i == excluded_index or not (districts[i] is Dictionary):
			continue
		var district: Dictionary = districts[i]
		if not bool(district.get("destroyed", false)):
			return i
	return -1


func _first_runtime_alive_district_with_supply(main: Node, excluded_index: int = -1) -> int:
	var districts := _runtime_districts(main)
	for i in range(districts.size()):
		if i == excluded_index or not (districts[i] is Dictionary):
			continue
		var district: Dictionary = districts[i]
		var choices_variant: Variant = district.get("card_choices", [])
		var choices: Array = choices_variant if choices_variant is Array else []
		if not bool(district.get("destroyed", false)) and not choices.is_empty():
			return i
	return -1


func _runtime_hand_card_control(runtime_screen: Control, slot_index: int) -> Control:
	var hand_rack := runtime_screen.find_child("HandRack", true, false) as Control
	if hand_rack == null:
		return null
	var wanted_id := "hand_%d" % slot_index
	for child in hand_rack.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if not control.has_method("get_card_data"):
			continue
		var data_variant: Variant = control.call("get_card_data")
		var data: Dictionary = data_variant if data_variant is Dictionary else {}
		if str(data.get("id", "")) == wanted_id:
			return control
	return null


func _runtime_district_supply_market_card_control(node: Node, card_name: String) -> Control:
	if node == null:
		return null
	if node.has_method("get_card_name") and String(node.call("get_card_name")) == card_name and node is Control:
		return node as Control
	for child in node.get_children():
		var found := _runtime_district_supply_market_card_control(child, card_name)
		if found != null:
			return found
	return null


func _double_click_card_control(card: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	card.call("_gui_input", event)


func _single_click_card_control(card: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = false
	card.call("_gui_input", event)


func _drag_card_control_to_screen(card: Control, drop_screen_position: Vector2) -> void:
	var start_screen_position := card.get_global_rect().get_center()
	var local_center := card.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local_center
	press.global_position = start_screen_position
	card.gui_input.emit(press)
	var motion := InputEventMouseMotion.new()
	motion.position = local_center + Vector2(20.0, -20.0)
	motion.global_position = drop_screen_position
	motion.relative = drop_screen_position - start_screen_position
	card.gui_input.emit(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = local_center
	release.global_position = drop_screen_position
	card.gui_input.emit(release)


func _click_map_control(map_view: Control, position: Vector2, double_click: bool) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.double_click = double_click
	map_view.call("_gui_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	map_view.call("_gui_input", release)


func _runtime_district_city(main: Node, district_index: int) -> Dictionary:
	var districts := _runtime_districts(main)
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return {}
	var district: Dictionary = districts[district_index]
	var city_variant: Variant = district.get("city", {})
	return city_variant if city_variant is Dictionary else {}


func _runtime_active_city_count(main: Node) -> int:
	var count := 0
	var districts := _runtime_districts(main)
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district: Dictionary = district_variant
		var city_variant: Variant = district.get("city", {})
		var city: Dictionary = city_variant if city_variant is Dictionary else {}
		if not city.is_empty() and bool(city.get("active", true)):
			count += 1
	return count


func _runtime_owned_monster_count(main: Node, player_index: int) -> int:
	var count := 0
	var monsters_variant: Variant = main.get("auto_monsters")
	var monsters: Array = monsters_variant if monsters_variant is Array else []
	for monster_variant in monsters:
		if not (monster_variant is Dictionary):
			continue
		var monster: Dictionary = monster_variant
		if int(monster.get("owner", -1)) == player_index and not bool(monster.get("down", false)):
			count += 1
	return count


func _runtime_players(main: Node) -> Array:
	var players_variant: Variant = main.get("players")
	return players_variant if players_variant is Array else []


func _runtime_player(main: Node, player_index: int) -> Dictionary:
	var players := _runtime_players(main)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {}
	return players[player_index] as Dictionary


func _runtime_player_skill_fixture(main: Node, player_index: int) -> Dictionary:
	var player := _runtime_player(main, player_index)
	var slots_variant: Variant = player.get("slots", [])
	var slots: Array = slots_variant if slots_variant is Array else []
	for i in range(slots.size()):
		if slots[i] is Dictionary:
			return {"slot_index": i, "skill": (slots[i] as Dictionary).duplicate(true)}
	if main.has_method("_make_skill"):
		var made_skill_variant: Variant = main.call("_make_skill", "移动1")
		if made_skill_variant is Dictionary:
			return {"slot_index": -1, "skill": (made_skill_variant as Dictionary).duplicate(true)}
	return {"slot_index": -1, "skill": {"name": "测试卡牌", "cost": 0}}


func _prepare_runtime_open_card_auction(main: Node) -> void:
	var first_fixture := _runtime_player_skill_fixture(main, 0)
	var second_fixture := _runtime_player_skill_fixture(main, 1)
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [
		{
			"resolution_id": 9001,
			"queued_order": 1,
			"player_index": 0,
			"slot_index": int(first_fixture.get("slot_index", -1)),
			"skill": first_fixture.get("skill", {}),
			"tip": 40,
			"play_cash_cost": 0,
		},
		{
			"resolution_id": 9002,
			"queued_order": 2,
			"player_index": 1,
			"slot_index": int(second_fixture.get("slot_index", -1)),
			"skill": second_fixture.get("skill", {}),
			"tip": 80,
			"play_cash_cost": 0,
		},
	])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_auction_open", true)
	main.set("card_resolution_auction_timer", 4.0)
	main.set("card_resolution_simultaneous_timer", 0.0)
	main.set("card_resolution_batch_locked", false)
	main.set("card_resolution_batch_reference_player", 0)


func _clear_runtime_card_auction_fixture(main: Node) -> void:
	main.set("active_card_resolution", {})
	main.set("card_resolution_queue", [])
	main.set("next_card_resolution_queue", [])
	main.set("card_resolution_auction_open", false)
	main.set("card_resolution_auction_timer", 0.0)
	main.set("card_resolution_simultaneous_timer", 0.0)
	main.set("card_resolution_batch_locked", false)


func _clear_runtime_player_action_cooldown(main: Node, player_index: int) -> void:
	_set_runtime_player_action_cooldown(main, player_index, 0.0)


func _set_runtime_player_action_cooldown(main: Node, player_index: int, cooldown: float) -> void:
	var players := _runtime_players(main).duplicate(true)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["action_cooldown"] = maxf(0.0, cooldown)
	players[player_index] = player
	main.set("players", players)


func _runtime_player_cash(main: Node, player_index: int) -> int:
	return int(_runtime_player(main, player_index).get("cash", 0))


func _runtime_player_card_names(main: Node, player_index: int) -> Array[String]:
	var result: Array[String] = []
	var slots: Array = _runtime_player(main, player_index).get("slots", [])
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot: Dictionary = slot_variant
		var name := String(slot.get("name", ""))
		if name != "":
			result.append(name)
	return result


func _runtime_player_counted_hand_size(main: Node, player_index: int) -> int:
	if main.has_method("_player_counted_hand_size"):
		var player := _runtime_player(main, player_index)
		if not player.is_empty():
			return int(main.call("_player_counted_hand_size", player))
	var count := 0
	var slots: Array = _runtime_player(main, player_index).get("slots", [])
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _runtime_player_has_card_family(main: Node, player_index: int, card_name: String) -> bool:
	var target_family := _runtime_skill_family(main, card_name)
	if target_family == "":
		target_family = card_name
	var slots: Array = _runtime_player(main, player_index).get("slots", [])
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot: Dictionary = slot_variant
		var slot_name := String(slot.get("name", ""))
		if slot_name == card_name or _runtime_skill_family(main, slot_name) == target_family:
			return true
	return false


func _runtime_public_log_count(main: Node) -> int:
	var logs_variant: Variant = main.get("log_lines")
	var logs: Array = logs_variant if logs_variant is Array else []
	return logs.size()


func _runtime_public_log_slice_has_secret(main: Node, start_index: int, needles: Array) -> bool:
	var logs_variant: Variant = main.get("log_lines")
	var logs: Array = logs_variant if logs_variant is Array else []
	for i in range(maxi(0, start_index), logs.size()):
		var line := String(logs[i])
		for needle_variant in needles:
			var needle := String(needle_variant)
			if needle != "" and line.contains(needle):
				return true
	return false


func _runtime_skill_family(main: Node, card_name: String) -> String:
	if card_name == "":
		return ""
	if main.has_method("_skill_family"):
		return String(main.call("_skill_family", card_name))
	return card_name


func _runtime_card_resolution_entry_count(main: Node) -> int:
	var count := 0
	for list_name in ["card_resolution_queue", "next_card_resolution_queue", "resolved_card_history"]:
		var list_variant: Variant = main.get(list_name)
		if list_variant is Array:
			count += (list_variant as Array).size()
	var active_variant: Variant = main.get("active_card_resolution")
	var active: Dictionary = active_variant if active_variant is Dictionary else {}
	if not active.is_empty():
		count += 1
	return count


func _check_runtime_table_snapshot_bridge() -> void:
	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var split_packed := load("res://scenes/ui/GameScreen.tscn") as PackedScene
	_expect(main_packed != null, "runtime main scene loads for table snapshot bridge")
	_expect(split_packed != null, "split GameScreen loads for table snapshot bridge")
	if main_packed == null or split_packed == null:
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var main := main_packed.instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	_expect(main.has_method("_runtime_table_snapshot"), "main runtime exposes a TableSnapshot-compatible adapter")
	var runtime_screen := main.find_child("RuntimeGameScreen", true, false) as Control
	var legacy_shell := main.find_child("LegacyRuntimeTable", true, false) as Control
	var runtime_map := main.get("map_view") as Control
	var runtime_overlay_host: Node = null
	var map_host: Control = null
	if runtime_screen != null:
		map_host = runtime_screen.find_child("MapHost", true, false) as Control
		runtime_overlay_host = runtime_screen.find_child("OverlayLayer", true, false)
	_expect(runtime_screen != null and runtime_screen.visible, "main runtime mounts the split GameScreen as the visible product layer")
	_expect(main.has_method("_uses_split_runtime_table") and bool(main.call("_uses_split_runtime_table")), "main runtime reports split table mode so legacy player panel refresh stays inactive by default")
	_expect(legacy_shell != null and not legacy_shell.visible, "legacy generated table remains in-tree as a hidden rollback shell")
	_expect(legacy_shell != null and legacy_shell.process_mode == Node.PROCESS_MODE_DISABLED and legacy_shell.mouse_filter == Control.MOUSE_FILTER_IGNORE, "hidden legacy rollback shell is disabled and cannot intercept split-table runtime input")
	_expect(legacy_shell != null and legacy_shell.get_child_count() == 0, "default runtime skips constructing the legacy generated table tree")
	_expect(map_host != null and runtime_map != null and runtime_map.get_parent() == map_host, "main runtime attaches the interactive MapView into split PlanetBoard MapHost")
	_expect(runtime_overlay_host != null, "main runtime exposes the split OverlayLayer as the host for transient table surfaces")
	var hosted_overlay_nodes := {
		"fullscreen map overlay": main.get("full_map_overlay") as Control,
		"card resolution banner overlay": main.get("card_resolution_overlay") as Control,
		"bottom countdown overlay": main.get("bottom_countdown_overlay") as Control,
		"district supply drawer overlay": main.get("district_supply_overlay") as Control,
		"menu modal overlay": main.get("menu_overlay") as Control,
	}
	for overlay_label in hosted_overlay_nodes.keys():
		var overlay_node := hosted_overlay_nodes[overlay_label] as Control
		_expect(overlay_node != null and overlay_node.get_parent() == runtime_overlay_host, "main runtime hosts %s inside split OverlayLayer instead of the root scene" % overlay_label)
	_expect(main.has_method("_on_runtime_game_screen_action_requested"), "main runtime handles split GameScreen action signals")
	var snapshot_variant: Variant = main.call("_runtime_table_snapshot") if main.has_method("_runtime_table_snapshot") else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	_expect(snapshot.has("top_bar"), "runtime snapshot contains top_bar")
	_expect(snapshot.has("right_inspector"), "runtime snapshot contains right_inspector")
	_expect(snapshot.has("player_board"), "runtime snapshot contains player_board")
	_expect(snapshot.has("card_track"), "runtime snapshot contains card_track")
	_expect(snapshot.has("planet"), "runtime snapshot contains planet")
	_expect(snapshot.has("first_run_coach"), "runtime snapshot contains first_run_coach")
	_expect(not _variant_contains_callable(snapshot), "runtime TableSnapshot bridge emits data-only snapshots without Callable rule handles")
	var snapshot_source_variant: Variant = main.call("_runtime_table_snapshot_source") if main.has_method("_runtime_table_snapshot_source") else {}
	var snapshot_source: Dictionary = snapshot_source_variant if snapshot_source_variant is Dictionary else {}
	_expect(not _variant_contains_callable(snapshot_source), "runtime TableSnapshot source strips internal Callable action targets before split UI sync")
	var top_bar: Dictionary = snapshot.get("top_bar", {}) if snapshot.get("top_bar", {}) is Dictionary else {}
	var right_inspector: Dictionary = snapshot.get("right_inspector", {}) if snapshot.get("right_inspector", {}) is Dictionary else {}
	var player_board: Dictionary = snapshot.get("player_board", {}) if snapshot.get("player_board", {}) is Dictionary else {}
	var first_run_coach_snapshot: Dictionary = snapshot.get("first_run_coach", {}) if snapshot.get("first_run_coach", {}) is Dictionary else {}
	_expect(str(top_bar.get("identity", "")).strip_edges() != "", "runtime top_bar snapshot has first-glance identity")
	_expect(str(top_bar.get("selected_district", "")).strip_edges() != "", "runtime top_bar snapshot has selected district")
	_expect(str(top_bar.get("primary_action", "")).strip_edges() != "", "runtime top_bar snapshot has primary action")
	_expect(str(right_inspector.get("why", "")).strip_edges() != "", "runtime right_inspector snapshot explains why/availability")
	_expect(right_inspector.get("requirements", []) is Array and (right_inspector.get("requirements", []) as Array).size() > 0, "runtime right_inspector snapshot has requirement chips")
	_expect(right_inspector.get("deep_links", []) is Array and (right_inspector.get("deep_links", []) as Array).size() > 0, "runtime right_inspector snapshot has deeper-detail links")
	_expect(player_board.get("actions", []) is Array and (player_board.get("actions", []) as Array).size() > 0, "runtime player_board snapshot has compact actions")
	_expect(first_run_coach_snapshot.has("recommended_setup"), "runtime first_run_coach snapshot carries recommended first-run setup metadata")
	var screen := split_packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	_expect(screen != null and screen.has_method("apply_state"), "split GameScreen can consume runtime table snapshot")
	if screen != null and screen.has_method("apply_state"):
		screen.call("apply_state", snapshot)
		await process_frame
		_expect(screen.find_child("TopBar", true, false) != null and screen.find_child("RightInspector", true, false) != null and screen.find_child("PlayerBoard", true, false) != null, "runtime snapshot renders through split product-layer scene")
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [7, 6, 2, 4, 3])
	main.call("_new_game")
	await process_frame
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await process_frame
	var runtime_menu_button: Button = null
	var runtime_end_turn_button: Button = null
	if runtime_screen != null:
		runtime_menu_button = runtime_screen.find_child("MenuButton", true, false) as Button
		runtime_end_turn_button = runtime_screen.find_child("EndTurnButton", true, false) as Button
	var runtime_menu_overlay := main.get("menu_overlay") as Control
	_expect(runtime_end_turn_button != null and not runtime_end_turn_button.visible, "runtime split TopBar keeps end-turn button hidden unless a snapshot explicitly enables it")
	if runtime_menu_button != null:
		runtime_menu_button.emit_signal("pressed")
		await process_frame
		_expect(runtime_menu_overlay != null and runtime_menu_overlay.visible, "runtime split TopBar menu button opens the existing menu overlay")
	var live_snapshot_variant: Variant = main.call("_runtime_table_snapshot")
	var live_snapshot: Dictionary = live_snapshot_variant if live_snapshot_variant is Dictionary else {}
	var live_player_board: Dictionary = live_snapshot.get("player_board", {}) if live_snapshot.get("player_board", {}) is Dictionary else {}
	var live_right_inspector: Dictionary = live_snapshot.get("right_inspector", {}) if live_snapshot.get("right_inspector", {}) is Dictionary else {}
	var live_first_run_coach: Dictionary = live_snapshot.get("first_run_coach", {}) if live_snapshot.get("first_run_coach", {}) is Dictionary else {}
	var live_deep_links: Array = live_right_inspector.get("deep_links", []) if live_right_inspector.get("deep_links", []) is Array else []
	_expect(live_player_board.get("hand_cards", []) is Array and (live_player_board.get("hand_cards", []) as Array).size() > 0, "runtime player_board snapshot includes live hand-card data after a new run starts")
	_expect(live_player_board.get("quick_actions", []) is Array and (live_player_board.get("quick_actions", []) as Array).size() == 4, "runtime player_board snapshot includes Build/Rack/Buy/Play scan chips after a new run starts")
	_expect(live_player_board.get("table_state_lamps", []) is Array and (live_player_board.get("table_state_lamps", []) as Array).size() > 0, "runtime player_board snapshot includes table-state lamps after a new run starts")
	_expect(live_player_board.get("readiness_chips", []) is Array and (live_player_board.get("readiness_chips", []) as Array).size() > 0, "runtime player_board snapshot includes action-readiness chips after a new run starts")
	_expect(live_player_board.get("actions", []) is Array and (live_player_board.get("actions", []) as Array).size() > 0, "runtime player_board snapshot includes live compact actions after a new run starts")
	_expect(live_right_inspector.get("requirements", []) is Array and (live_right_inspector.get("requirements", []) as Array).size() > 0, "runtime right_inspector snapshot includes live selected-region requirements after a new run starts")
	_expect(bool(live_first_run_coach.get("visible", false)) and str(live_first_run_coach.get("stage", "")).strip_edges() != "", "runtime first-run coach renders a live next-step phase after a new run starts")
	_expect(_action_list_has_id(live_deep_links, "detail_region") and _action_list_has_id(live_deep_links, "detail_cards") and not _action_list_has_id(live_deep_links, "codex_region"), "runtime right_inspector deep links open the 30-second drawer layer before Codex")
	_prepare_runtime_open_card_auction(main)
	_force_runtime_screen_sync(main)
	await process_frame
	var auction_snapshot_variant: Variant = main.call("_runtime_table_snapshot")
	var auction_snapshot: Dictionary = auction_snapshot_variant if auction_snapshot_variant is Dictionary else {}
	var auction_player_board: Dictionary = auction_snapshot.get("player_board", {}) if auction_snapshot.get("player_board", {}) is Dictionary else {}
	var auction_bid_board: Dictionary = auction_player_board.get("bid_board", {}) if auction_player_board.get("bid_board", {}) is Dictionary else {}
	var auction_bid_chips: Array = auction_bid_board.get("chips", []) if auction_bid_board.get("chips", []) is Array else []
	var auction_track_links: Array = auction_bid_board.get("track_links", []) if auction_bid_board.get("track_links", []) is Array else []
	var auction_bid_actions: Array = auction_bid_board.get("actions", []) if auction_bid_board.get("actions", []) is Array else []
	var auction_cluster_labels: Array[String] = []
	for chip_variant in auction_bid_chips:
		if not (chip_variant is Dictionary):
			continue
		var chip: Dictionary = chip_variant
		auction_cluster_labels.append(str(chip.get("label", "")))
	var auction_track_labels: Array[String] = []
	var leader_link: Dictionary = {}
	var player_link: Dictionary = {}
	for link_variant in auction_track_links:
		if link_variant is Dictionary:
			var link: Dictionary = link_variant
			auction_track_labels.append(str(link.get("label", "")))
			if str(link.get("label", "")) == "领跑":
				leader_link = link
			elif str(link.get("label", "")) == "我的牌":
				player_link = link
	_expect(str(auction_bid_board.get("phase", "")).contains("竞价") and auction_cluster_labels.has("最高") and auction_cluster_labels.has("我的") and auction_cluster_labels.has("本批") and auction_cluster_labels.has("下批"), "runtime player_board snapshot routes open card-auction state into the dedicated BidBoard")
	_expect(auction_track_labels.has("领跑") and auction_track_labels.has("我的牌"), "runtime BidBoard snapshot links bid state back to the public card track leader and the current player's queued card")
	_expect(str(leader_link.get("id", "")) == "track_select_9002" and str(leader_link.get("state", "")).contains("¥80") and str(player_link.get("id", "")) == "track_select_9001", "runtime BidBoard points the leader link at the actual highest public bid and keeps the current player's queued-card link separate")
	_expect(_action_list_has_id(auction_bid_actions, "bid_plus_10") and _action_list_has_id(auction_bid_actions, "bid_set_80") and _action_list_has_id(auction_bid_actions, "bid_set_90") and _action_list_has_id(auction_bid_actions, "bid_reset"), "runtime BidBoard snapshot exposes conservative, match, overtake, and reset bid actions")
	if screen != null and screen.has_method("apply_state"):
		screen.call("apply_state", auction_snapshot)
		await process_frame
		var auction_bid_board_node := screen.find_child("PlayerBidBoard", true, false)
		var auction_bid_chip_row := screen.find_child("BidBoardChipRow", true, false)
		var auction_bid_track_link_row := screen.find_child("BidBoardTrackLinkRow", true, false)
		var auction_bid_action_row := screen.find_child("BidBoardActionRow", true, false)
		var auction_bid_board_text := _node_tree_text(auction_bid_board_node) if auction_bid_board_node != null else ""
		_expect(auction_bid_chip_row != null and auction_bid_chip_row.get_child_count() >= 4, "split GameScreen renders open card-auction state inside the dedicated BidBoard instead of the readiness row")
		_expect(auction_bid_board_text.contains("竞价") and auction_bid_board_text.contains("最高") and auction_bid_board_text.contains("我的") and auction_bid_board_text.contains("本批") and auction_bid_board_text.contains("领跑"), "split BidBoard keeps open card-auction and public-track labels visible on the table")
		_expect(auction_bid_track_link_row != null and auction_bid_track_link_row.get_child_count() >= 2, "split BidBoard renders clickable public-track pointer slots instead of burying them in the status sentence")
		_expect(auction_bid_action_row != null and auction_bid_action_row.get_child_count() >= 4, "split BidBoard renders public bid increment and reset buttons")
		var public_track_slot_for_hover := screen.find_child("PublicTrackSlot", true, false) as Control
		if public_track_slot_for_hover != null:
			public_track_slot_for_hover.emit_signal("mouse_entered")
			await process_frame
			var hovered_bid_link_marker := screen.find_child("BidBoardTrackLinkHover", true, false)
			_expect(hovered_bid_link_marker != null, "hovering a public-track slot temporarily highlights its matching BidBoard pointer")
			public_track_slot_for_hover.emit_signal("mouse_exited")
			await process_frame
			hovered_bid_link_marker = screen.find_child("BidBoardTrackLinkHover", true, false)
			_expect(hovered_bid_link_marker == null, "leaving a public-track slot clears the temporary BidBoard pointer highlight")
	var runtime_leader_link_button := _find_visible_button_containing(runtime_screen, "领跑")
	_expect(runtime_leader_link_button != null and not runtime_leader_link_button.disabled, "runtime BidBoard leader pointer is a clickable public-track selection control")
	if runtime_leader_link_button != null and not runtime_leader_link_button.disabled:
		runtime_leader_link_button.emit_signal("mouse_entered")
		await process_frame
		var hovered_track_marker := runtime_screen.find_child("PublicTrackSlotHover", true, false)
		var runtime_track_focus_ribbon := runtime_screen.find_child("TrackFocusRibbon", true, false) as Control
		var runtime_track_focus_label := runtime_screen.find_child("TrackFocusLabel", true, false) as Label
		var runtime_hover_inspector_text := _node_tree_text(runtime_screen.find_child("RightInspector", true, false))
		_expect(hovered_track_marker != null, "hovering the BidBoard leader pointer temporarily highlights the matching public-track slot")
		_expect(runtime_track_focus_ribbon != null and runtime_track_focus_ribbon.visible and runtime_track_focus_label != null and runtime_track_focus_label.text.contains("竞价对照"), "hovering the BidBoard leader pointer opens the table-focus ribbon for the matching public-track card")
		_expect(runtime_hover_inspector_text.contains("牌轨详情") and runtime_hover_inspector_text.contains("线索档案"), "hovering the BidBoard leader pointer previews the matching public-track card in RightInspector")
		runtime_leader_link_button.emit_signal("mouse_exited")
		await process_frame
		hovered_track_marker = runtime_screen.find_child("PublicTrackSlotHover", true, false)
		_expect(hovered_track_marker == null, "leaving the BidBoard leader pointer clears the temporary public-track hover highlight")
		runtime_track_focus_ribbon = runtime_screen.find_child("TrackFocusRibbon", true, false) as Control
		_expect(runtime_track_focus_ribbon != null and not runtime_track_focus_ribbon.visible, "leaving the BidBoard leader pointer clears the temporary table-focus ribbon before a card is selected")
		runtime_leader_link_button.emit_signal("pressed")
		await process_frame
		_expect(int(main.get("selected_card_resolution_id")) == 9002, "clicking the BidBoard leader pointer selects the matching public-track card")
		_force_runtime_screen_sync(main)
		await process_frame
		var selected_track_marker := runtime_screen.find_child("PublicTrackSlotSelected", true, false)
		_expect(selected_track_marker != null, "public card track highlights the selected card after a BidBoard pointer click")
		runtime_track_focus_ribbon = runtime_screen.find_child("TrackFocusRibbon", true, false) as Control
		runtime_track_focus_label = runtime_screen.find_child("TrackFocusLabel", true, false) as Label
		_expect(runtime_track_focus_ribbon != null and runtime_track_focus_ribbon.visible and runtime_track_focus_label != null and runtime_track_focus_label.text.contains("已选牌轨"), "selected public-track cards keep a persistent short focus ribbon after BidBoard pointer click")
	var live_bid_before := int(main.call("_selected_card_tip_amount", 0)) if main.has_method("_selected_card_tip_amount") else 0
	var runtime_bid_plus_button := _find_visible_button_containing(runtime_screen, "+10")
	_expect(runtime_bid_plus_button != null and not runtime_bid_plus_button.disabled, "runtime BidBoard exposes an enabled +10 public-bid button for the current queued card")
	if runtime_bid_plus_button != null and not runtime_bid_plus_button.disabled:
		runtime_bid_plus_button.emit_signal("pressed")
		await process_frame
		var live_bid_after := int(main.call("_selected_card_tip_amount", 0)) if main.has_method("_selected_card_tip_amount") else live_bid_before
		_expect(live_bid_after == live_bid_before + 10, "runtime BidBoard +10 button routes through split action signals and raises the current public bid")
	_clear_runtime_card_auction_fixture(main)
	_force_runtime_screen_sync(main)
	await process_frame
	live_snapshot_variant = main.call("_runtime_table_snapshot")
	live_snapshot = live_snapshot_variant if live_snapshot_variant is Dictionary else {}
	live_player_board = live_snapshot.get("player_board", {}) if live_snapshot.get("player_board", {}) is Dictionary else {}
	var live_hand_cards: Array = live_player_board.get("hand_cards", []) if live_player_board.get("hand_cards", []) is Array else []
	if not live_hand_cards.is_empty():
		var first_card: Dictionary = live_hand_cards[0] if live_hand_cards[0] is Dictionary else {}
		var first_card_id := str(first_card.get("id", "hand_0"))
		var expected_play_id := "play_0"
		if first_card_id.begins_with("hand_"):
			expected_play_id = "play_%d" % int(first_card_id.substr("hand_".length()))
		main.call("_on_runtime_game_screen_card_selected", first_card)
		await process_frame
		var card_snapshot_variant: Variant = main.call("_runtime_table_snapshot")
		var card_snapshot: Dictionary = card_snapshot_variant if card_snapshot_variant is Dictionary else {}
		var card_inspector: Dictionary = card_snapshot.get("right_inspector", {}) if card_snapshot.get("right_inspector", {}) is Dictionary else {}
		var card_requirements: Array = card_inspector.get("requirements", []) if card_inspector.get("requirements", []) is Array else []
		var card_actions: Array = card_inspector.get("actions", []) if card_inspector.get("actions", []) is Array else []
		var card_deep_links: Array = card_inspector.get("deep_links", []) if card_inspector.get("deep_links", []) is Array else []
		_expect(str(card_inspector.get("title", "")).contains("卡牌"), "runtime right_inspector switches to selected hand-card detail")
		_expect(card_requirements.size() > 0, "runtime selected hand-card detail keeps play requirements")
		_expect(_action_list_has_id(card_actions, expected_play_id), "runtime selected hand-card detail exposes the matching play action")
		_expect((_action_list_has_id(card_deep_links, "detail_cards") or _action_list_has_id(card_deep_links, "detail_card")) and _action_list_has_id(card_deep_links, "detail_region") and not _action_list_has_id(card_deep_links, "codex_cards") and not _action_list_has_id(card_deep_links, "codex_region"), "runtime selected hand-card detail opens the 30-second drawer layer before Codex")
		live_snapshot = card_snapshot
	if screen != null and screen.has_method("apply_state"):
		screen.call("apply_state", live_snapshot)
		await process_frame
		var hand_rack := screen.find_child("HandRack", true, false)
		var status_lamps := screen.find_child("PlayerStatusLampRow", true, false)
		var readiness_chips := screen.find_child("PlayerReadinessChipRow", true, false)
		var card_deep_link_row := screen.find_child("InspectorDeepLinkRow", true, false)
		var card_side_drawer := screen.find_child("SideDrawerPanel", true, false)
		_expect(hand_rack != null and hand_rack.get_child_count() > 0, "split GameScreen renders live hand cards from the runtime snapshot bridge")
		_expect(status_lamps != null and status_lamps.get_child_count() > 0, "split GameScreen renders live table-state lamps from the runtime snapshot bridge")
		_expect(readiness_chips != null and readiness_chips.get_child_count() > 0, "split GameScreen renders live readiness chips from the runtime snapshot bridge")
		var card_action_ids: Array[String] = []
		if screen.has_signal("action_requested"):
			screen.connect("action_requested", func(action_id: String) -> void:
				card_action_ids.append(action_id)
			)
		if card_deep_link_row != null and card_deep_link_row.get_child_count() > 0 and card_deep_link_row.get_child(0) is Button:
			(card_deep_link_row.get_child(0) as Button).emit_signal("pressed")
			await process_frame
			_expect(card_side_drawer != null and card_side_drawer.visible, "split selected hand-card detail link opens OverlayLayer side drawer")
			_expect(card_action_ids.has("detail_cards") or card_action_ids.has("detail_card"), "split selected hand-card detail link emits detail action before Codex")
			_expect(not card_action_ids.has("codex_cards") and not card_action_ids.has("codex_card"), "split selected hand-card detail link does not jump straight to Card Codex")
	_check_named_controls_do_not_overlap(runtime_screen, ["TopBar", "PublicTrack", "TableArea", "PlayerBoard"], "runtime main split GameScreen", Vector2(viewport.size))
	_check_named_controls_do_not_overlap(runtime_screen, ["PlanetBoard", "RightInspector"], "runtime main split GameScreen", Vector2(viewport.size))
	_check_named_controls_inside_viewport(runtime_screen, ["TopBar", "PublicTrack", "TableArea", "PlayerBoard", "HandRack", "PlayerBidBoard", "PlayerMainActionDock", "PlayerStatusLampRow", "PlayerReadinessChipRow"], "runtime main split GameScreen", Vector2(viewport.size))
	_check_visible_buttons_inside_viewport(runtime_screen, "runtime main split GameScreen", Vector2(viewport.size))
	_check_planet_is_largest_runtime_surface(runtime_screen, "runtime main split GameScreen")
	_check_planet_board_square_stage_priority(runtime_screen)
	_check_public_track_thin(runtime_screen, "runtime main split GameScreen")
	_check_player_board_first_glance_actions(runtime_screen)
	_check_player_board_hand_rack_priority(runtime_screen)
	_check_right_inspector_collapses_empty_panels(runtime_screen, "runtime main split GameScreen")
	_check_main_table_text_is_scan_first(runtime_screen, "runtime main split GameScreen")
	var runtime_map_rect := Rect2()
	if map_host != null:
		runtime_map_rect = map_host.get_global_rect()
	_expect(runtime_map_rect.size.x > 200.0 and runtime_map_rect.size.y > 120.0, "runtime split PlanetBoard gives the interactive map a usable visible area")
	await _check_runtime_map_mouse_selection_flow(main, runtime_screen)
	await _check_runtime_main_action_dock_click_flow(main, runtime_screen)
	await _check_runtime_hand_card_double_click_play(main, runtime_screen)
	await _check_runtime_hand_card_drag_to_map_play(main, runtime_screen)
	await _check_runtime_blocked_hand_card_drag_reason(main, runtime_screen)
	await _check_runtime_market_card_double_click_purchase(main, runtime_screen)
	await _check_runtime_full_hand_private_discard_purchase(main, runtime_screen)
	root.remove_child(screen)
	screen.queue_free()
	viewport.remove_child(main)
	main.queue_free()
	root.remove_child(viewport)
	viewport.queue_free()


func _check_viewmodel_contracts() -> void:
	var action_dock_script := load("res://scripts/viewmodels/action_dock_snapshot.gd")
	var bid_board_script := load("res://scripts/viewmodels/bid_board_snapshot.gd")
	var overlay_script := load("res://scripts/viewmodels/overlay_layer_snapshot.gd")
	var card_codex_browser_script := load("res://scripts/viewmodels/card_codex_browser_snapshot.gd")
	var card_codex_detail_script := load("res://scripts/viewmodels/card_codex_detail_snapshot.gd")
	var card_script := load("res://scripts/viewmodels/card_view_snapshot.gd")
	var district_script := load("res://scripts/viewmodels/district_view_snapshot.gd")
	var player_script := load("res://scripts/viewmodels/player_board_snapshot.gd")
	var public_track_script := load("res://scripts/viewmodels/public_track_snapshot.gd")
	var planet_script := load("res://scripts/viewmodels/planet_board_snapshot.gd")
	var top_bar_script := load("res://scripts/viewmodels/top_bar_snapshot.gd")
	var inspector_script := load("res://scripts/viewmodels/right_inspector_snapshot.gd")
	var table_script := load("res://scripts/viewmodels/table_snapshot.gd")
	_expect(action_dock_script != null, "ActionDockSnapshot script loads")
	_expect(bid_board_script != null, "BidBoardSnapshot script loads")
	_expect(overlay_script != null, "OverlayLayerSnapshot script loads")
	_expect(card_codex_browser_script != null, "CardCodexBrowserSnapshot script loads")
	_expect(card_codex_detail_script != null, "CardCodexDetailSnapshot script loads")
	_expect(card_script != null, "CardViewSnapshot script loads")
	_expect(district_script != null, "DistrictViewSnapshot script loads")
	_expect(player_script != null, "PlayerBoardSnapshot script loads")
	_expect(public_track_script != null, "PublicTrackSnapshot script loads")
	_expect(planet_script != null, "PlanetBoardSnapshot script loads")
	_expect(top_bar_script != null, "TopBarSnapshot script loads")
	_expect(inspector_script != null, "RightInspectorSnapshot script loads")
	_expect(table_script != null, "TableSnapshot script loads")
	if action_dock_script == null or bid_board_script == null or overlay_script == null or card_codex_browser_script == null or card_codex_detail_script == null or card_script == null or district_script == null or player_script == null or public_track_script == null or planet_script == null or top_bar_script == null or inspector_script == null or table_script == null:
		return
	var action_dock: Variant = action_dock_script.new().apply_dictionary({
		"quick_actions": [{"id": "build", "label": "建城", "state": "ready", "active": true}],
		"actions": [{"id": "summon", "label": "首召", "state": "ready"}],
	})
	var bid_board: Variant = bid_board_script.new().apply_dictionary({
		"title": "牌桌竞价",
		"phase": "竞价 4s",
		"status": "候补牌参拍中｜当前¥40｜最高¥80",
		"chips": [{"label": "最高", "state": "¥80", "active": true}],
		"track_links": [{"id": "track_select_9002", "label": "领跑", "state": "竞拍1 ¥80", "active": true, "selected": true}],
		"actions": [{"id": "bid_plus_10", "label": "保守+10", "active": true}],
	})
	var default_action_dock: Variant = action_dock_script.new().apply_dictionary({})
	var card: Variant = card_script.new().apply_dictionary({"name": "相位否决", "rank": "I", "type": "互动", "effect": "反制一次直接互动。"})
	var district: Variant = district_script.new().apply_dictionary({"name": "雾港区", "summary": "海陆商路交界。"})
	var player: Variant = player_script.new().apply_dictionary({
		"title": "玩家板",
		"identity": "赤港财团",
		"cash_text": "¥ 1300",
		"gdp_text": "+22/s",
		"goal_text": "5000",
		"goal_ratio": 0.25,
		"quick_actions": [{"id": "build", "label": "建城", "state": "ready", "active": true}],
		"table_state_lamps": [{"text": "桌态", "state": "竞价", "active": true}],
		"readiness_chips": [{"text": "选区就绪", "active": true}],
		"progress_path": [{"text": "首召", "state": "已召", "active": true}, {"text": "建城", "state": "待建", "active": false}],
		"bid_board": bid_board.to_ui_dictionary(),
		"selected_district_summary": "雾港区",
		"actions": [{"id": "summon", "label": "首召"}],
		"hand_cards": [card.to_ui_dictionary()],
	})
	var top_bar: Variant = top_bar_script.new().apply_dictionary(player.to_ui_dictionary())
	var inspector: Variant = inspector_script.new().apply_dictionary({
		"title": "当前说明",
		"why": "因为怪兽在邻区，所以牌架可用。",
		"district": {
			"title": "雾港区",
			"detail": "海陆商路交界。这里是完整区域说明，会进入详情抽屉而不是常驻主桌。它还包含供需、怪兽路径、历史事件、牌架购买条件、经济线索、城市业主推理、怪兽下注、商路风险和下一步行动原因。",
			"chips": [{"text": "怪兽邻近"}],
		},
		"requirements": ["怪兽邻近", "现金足够"],
		"actions": [{"id": "market", "label": "牌架"}],
		"deep_links": [{"id": "codex_region", "label": "区域详情"}],
	})
	var table: Variant = table_script.new().apply_dictionary({
		"card_track": [{"label": "公开牌", "slot": 1, "state": "current", "cost": "¥80"}],
		"district": district.to_ui_dictionary(),
		"planet": {
			"title": "星球赌桌",
			"left_entries": [{"label": "星区", "value": "8区", "active": true}],
			"right_entries": [{"label": "怪兽", "value": "1只", "active": true}],
		},
		"player_board": player.to_ui_dictionary(),
		"right_inspector": inspector.to_ui_dictionary(),
	})
	var overlay: Variant = overlay_script.new().apply_side_drawer("detail_region", inspector.to_ui_dictionary())
	var card_codex_browser: Variant = card_codex_browser_script.new().apply_dictionary({
		"names": ["phase_beast_i", "orbital_finance_i", "weather_break_i"],
		"columns": 2,
		"rows": 1,
		"page_index": 0,
		"filter_id": "monster",
		"selected_card": "missing_card",
		"icon_legend": "图标：◆怪兽 ◇商品 ☄天气",
		"filters": [
			{"id": "monster", "label": "怪兽牌", "short_label": "怪兽", "icon": "◆", "count": 2, "accent": Color("#fb7185")},
			{"id": "weather", "label": "天气干预", "short_label": "天气", "icon": "☄", "count": 0, "accent": Color("#38bdf8")},
		],
		"cards": [
			{
				"card_name": "phase_beast_i",
				"title": "◆ 相位兽｜I",
				"title_tooltip": "相位兽 I",
				"art_text": "相位兽\n怪兽",
				"kind": "monster",
				"chips": [{"text": "¥2", "tooltip": "费用", "fg": Color("#fef3c7"), "accent": Color("#fb7185")}],
				"route": "怪兽路线",
				"effect": "邻区威胁上升",
				"accent": Color("#fb7185"),
			},
			{"card_name": "orbital_finance_i", "title": "¥ 轨道融资｜I", "route": "金融投机", "effect": "现金流上升", "accent": Color("#facc15")},
			{"card_name": "weather_break_i", "title": "☄ 裂隙天气｜I", "route": "天气博弈", "effect": "天气扰动", "accent": Color("#38bdf8")},
		],
		"preview": {"title": "悬停预览：◆ 相位兽", "body": "路线：怪兽｜邻区威胁", "accent": Color("#fb7185")},
	})
	var card_codex_detail: Variant = card_codex_detail_script.new().apply_dictionary({
		"accent": Color("#fb7185"),
		"tooltip": "完整卡牌公开说明",
		"card_face": {
			"name": "◆ 相位兽 I",
			"cost": "¥2",
			"effect": "邻区威胁上升。",
			"type": "怪兽路线",
			"rank": "I",
			"accent": Color("#fb7185"),
		},
		"summary": {
			"header_chips": [
				{"text": "◆怪兽", "accent": Color("#fb7185"), "tooltip": "卡牌类型"},
				{"text": "怪兽路线", "accent": Color("#c084fc"), "tooltip": "策略路线"},
			],
			"chips": [{"text": "¥2", "tooltip": "费用", "fg": Color("#fef3c7"), "accent": Color("#fb7185")}],
			"effect": "速读：压迫邻区｜热度上升",
			"effect_tooltip": "完整效果",
			"accent": Color("#fb7185"),
		},
		"tactical_entries": [
			{"title": "何时拿", "body": "想铺怪兽压力时拿。", "accent": Color("#fb7185")},
			{"title": "怎么配", "body": "配合诱导与赌局。", "accent": Color("#38bdf8")},
			{"title": "会暴露", "body": "目标怪兽公开。", "accent": Color("#f472b6")},
		],
		"facts": [
			{"title": "◎ 牌面定位", "body": "地图压力", "meta": "◆怪兽｜路线", "accent": Color("#fb7185")},
			{"title": "¥ 费用与门槛", "body": "购买 ¥2", "meta": "目标:怪兽", "accent": Color("#facc15")},
		],
		"upgrades": [
			{"roman": "I", "price": "¥2", "band": "轻量", "body": "热度+2", "accent": Color("#fb7185")},
			{"roman": "II", "price": "¥2", "band": "标准", "body": "热度+3", "accent": Color("#fb923c")},
		],
		"resolution": {"title": "◇ 结算演出", "body": "所有玩家看见卡面。", "meta": "出牌者匿名。", "accent": Color("#fb7185")},
	})
	var public_track: Variant = public_track_script.new().apply_entries([{
		"id": "track_42",
		"label": "公开牌",
		"slot": 1,
		"state": "current",
		"cost": "¥80",
		"resolution_id": 42,
		"card_name": "orbital_finance_i",
		"select_action": "track_select_42",
		"open_action": "track_open_orbital_finance_i",
		"requirements": [{"text": "当前"}, {"text": "归属:匿名"}],
		"actions": [{"id": "track_select_42", "label": "选中竞猜"}, {"id": "track_intel_42", "label": "线索档案"}],
		"deep_links": [{"id": "track_intel_42", "label": "线索档案"}, {"id": "track_open_orbital_finance_i", "label": "卡牌详情"}],
	}])
	var planet: Variant = planet_script.new().apply_dictionary({
		"title": "星球赌桌",
		"hint": "中央地图保留最大视觉中心",
		"left_entries": [{"label": "星区", "value": "8区", "active": true}],
		"right_entries": [{"label": "怪兽", "value": "1只", "active": true}],
	})
	var action_dock_ui: Dictionary = action_dock.to_ui_dictionary()
	var action_quick: Array = action_dock_ui.get("quick_actions", []) if action_dock_ui.get("quick_actions", []) is Array else []
	var action_primary: Array = action_dock_ui.get("actions", []) if action_dock_ui.get("actions", []) is Array else []
	var default_quick: Array = default_action_dock.to_ui_dictionary().get("quick_actions", []) if default_action_dock.to_ui_dictionary().get("quick_actions", []) is Array else []
	var bid_board_ui: Dictionary = bid_board.to_ui_dictionary()
	var bid_track_links: Array = bid_board_ui.get("track_links", []) if bid_board_ui.get("track_links", []) is Array else []
	var drawer: Dictionary = overlay.to_side_drawer_dictionary()
	var drawer_actions: Array = drawer.get("actions", []) if drawer.get("actions", []) is Array else []
	var drawer_chips: Array = drawer.get("chips", []) if drawer.get("chips", []) is Array else []
	var drawer_sections: Array = drawer.get("sections", []) if drawer.get("sections", []) is Array else []
	var card_browser_ui: Dictionary = card_codex_browser.to_ui_dictionary()
	var card_browser_filters: Array = card_browser_ui.get("filters", []) if card_browser_ui.get("filters", []) is Array else []
	var card_browser_cards: Array = card_browser_ui.get("cards", []) if card_browser_ui.get("cards", []) is Array else []
	var card_detail_ui: Dictionary = card_codex_detail.to_ui_dictionary()
	var card_detail_summary: Dictionary = card_detail_ui.get("summary", {}) if card_detail_ui.get("summary", {}) is Dictionary else {}
	var card_detail_tactical: Dictionary = card_detail_ui.get("tactical", {}) if card_detail_ui.get("tactical", {}) is Dictionary else {}
	var card_detail_tactical_entries: Array = card_detail_tactical.get("entries", []) if card_detail_tactical.get("entries", []) is Array else []
	var card_detail_upgrades: Array = card_detail_ui.get("upgrades", []) if card_detail_ui.get("upgrades", []) is Array else []
	_expect(action_quick.size() == 1 and action_quick[0].get("state") == "就绪" and action_primary.size() == 1 and action_primary[0].get("disabled") == false, "ActionDockSnapshot normalizes quick and primary action states for UI rendering")
	_expect(action_quick.size() == 1 and action_quick[0].get("shortcut") == "1", "ActionDockSnapshot assigns numeric shortcuts to supplied quick actions")
	_expect(default_quick.size() == 4 and default_quick[0].get("label") == "建城" and default_quick[0].get("shortcut") == "1" and default_quick[3].get("label") == "出牌" and default_quick[3].get("shortcut") == "4", "ActionDockSnapshot supplies the four first-glance quick actions and numeric shortcuts when source data is absent")
	_expect(bid_board_ui.get("chips", []).size() == 1 and bid_track_links.size() == 1 and str((bid_track_links[0] as Dictionary).get("id", "")) == "track_select_9002" and bool((bid_track_links[0] as Dictionary).get("selected", false)) and bid_board_ui.get("actions", []).size() == 1 and bid_board_ui.get("phase") == "竞价 4s", "BidBoardSnapshot normalizes public bid chips, clickable track links, selected state, and bid actions before PlayerBoard renders them")
	_expect(card.to_ui_dictionary().get("name") == "相位否决", "CardViewSnapshot emits card UI dictionaries")
	_expect(district.to_ui_dictionary().get("title") == "雾港区", "DistrictViewSnapshot emits district UI dictionaries")
	var player_hand_cards: Array = player.to_ui_dictionary().get("hand_cards", []) if player.to_ui_dictionary().get("hand_cards", []) is Array else []
	var player_first_hand_card: Dictionary = player_hand_cards[0] if player_hand_cards.size() > 0 and player_hand_cards[0] is Dictionary else {}
	_expect(player_hand_cards.size() == 1, "PlayerBoardSnapshot keeps hand cards")
	_expect(player_first_hand_card.get("presentation") == "mini_hand" and player_first_hand_card.get("detail_policy") == "right_inspector", "PlayerBoardSnapshot normalizes bottom hand cards as MiniCards and routes full detail out of the rack")
	_expect(player.to_ui_dictionary().get("quick_actions", []).size() == 1 and player.to_ui_dictionary().get("quick_actions", [])[0].get("state") == "就绪", "PlayerBoardSnapshot routes quick action scan chips through ActionDockSnapshot")
	_expect(player.to_ui_dictionary().get("table_state_lamps", []).size() == 1 and player.to_ui_dictionary().get("readiness_chips", []).size() == 1, "PlayerBoardSnapshot keeps table-state and readiness chips")
	_expect(player.to_ui_dictionary().get("progress_path", []).size() == 2 and player.to_ui_dictionary().get("progress_path", [])[0].get("text") == "首召", "PlayerBoardSnapshot keeps runtime path chips for the split PlayerBoard")
	_expect(player.to_ui_dictionary().get("bid_board", {}).get("actions", []).size() == 1 and player.to_ui_dictionary().get("bid_board", {}).get("chips", []).size() == 1 and player.to_ui_dictionary().get("bid_board", {}).get("track_links", []).size() == 1, "PlayerBoardSnapshot routes public bid-board state and track links through BidBoardSnapshot")
	_expect(player.to_ui_dictionary().get("identity") == "赤港财团" and player.to_ui_dictionary().get("selected_district_summary") == "雾港区", "PlayerBoardSnapshot keeps first-glance identity and selected district")
	_expect(player.to_ui_dictionary().get("primary_action") == "首召" and player.to_ui_dictionary().get("goal_ratio") > 0.2, "PlayerBoardSnapshot keeps primary action and goal progress")
	_expect(top_bar.to_ui_dictionary().get("identity") == "赤港财团" and top_bar.to_ui_dictionary().get("selected_district") == "雾港区", "TopBarSnapshot derives first-glance fields from player state")
	_expect(inspector.to_ui_dictionary().get("why").contains("怪兽") and inspector.to_ui_dictionary().get("requirements", []).size() == 2, "RightInspectorSnapshot keeps why text and requirement chips")
	_expect(inspector.to_ui_dictionary().get("actions", []).size() == 1 and inspector.to_ui_dictionary().get("actions", [])[0].get("label") == "牌架", "RightInspectorSnapshot routes inspector actions through ActionDockSnapshot")
	_expect(inspector.to_ui_dictionary().get("district", {}).get("detail") != inspector.to_ui_dictionary().get("district", {}).get("full_detail") and inspector.to_ui_dictionary().get("district", {}).get("full_detail", "").contains("完整区域说明"), "RightInspectorSnapshot separates table summary from full drawer detail")
	_expect(drawer.get("title") == "区域详情" and str(drawer.get("body", "")).contains("完整区域说明") and str(drawer.get("body", "")).contains("原因："), "OverlayLayerSnapshot builds full 30-second drawer body from inspector snapshot")
	_expect(drawer_sections.size() >= 3 and str(drawer_sections[0].get("title", "")).contains("对象") and _action_list_has_label(drawer_sections, "完整详情"), "OverlayLayerSnapshot builds sectioned 30-second drawer read order")
	_expect(drawer_chips.size() >= 2 and drawer_actions.size() == 1 and drawer_actions[0].get("id") == "codex_region", "OverlayLayerSnapshot normalizes drawer chips and Codex follow-up actions")
	_expect(card_browser_ui.get("page_text") == "第1/2页｜3张卡｜本页1-2" and card_browser_ui.get("selected_card") == "phase_beast_i" and card_browser_cards.size() == 2 and bool(card_browser_cards[0].get("selected", false)), "CardCodexBrowserSnapshot owns thumbnail pagination and selected-card fallback")
	_expect(card_browser_filters.size() == 2 and str(card_browser_filters[0].get("text", "")).contains("●◆怪兽·2") and bool(card_browser_filters[1].get("disabled", false)), "CardCodexBrowserSnapshot normalizes filter chips with counts and active state")
	_expect(card_detail_summary.get("title") == "扫牌顺序" and str(card_detail_summary.get("read_order", "")).contains("费用") and str(card_detail_ui.get("face_note", "")).contains("升级"), "CardCodexDetailSnapshot supplies the TCG read order and public card-face defaults")
	_expect(card_detail_tactical.get("title") == "牌桌用途｜先看这三格" and card_detail_tactical_entries.size() == 3 and card_detail_upgrades.size() == 2 and card_detail_ui.get("resolution", {}).get("meta") == "出牌者匿名。", "CardCodexDetailSnapshot normalizes tactical, upgrade, and public-resolution detail sections")
	var public_track_entry: Dictionary = public_track.to_ui_array()[0] if public_track.to_ui_array().size() > 0 and public_track.to_ui_array()[0] is Dictionary else {}
	var public_track_actions: Array = public_track_entry.get("actions", []) if public_track_entry.get("actions", []) is Array else []
	var public_track_deep_links: Array = public_track_entry.get("deep_links", []) if public_track_entry.get("deep_links", []) is Array else []
	_expect(public_track.to_ui_array().size() == 1 and public_track_entry.get("owner_hint") == "待猜", "PublicTrackSnapshot keeps hidden ownership as player-facing guess hints")
	_expect(int(public_track_entry.get("resolution_id", -1)) == 42 and public_track_entry.get("card_name") == "orbital_finance_i" and public_track_entry.get("select_action") == "track_select_42" and public_track_entry.get("open_action") == "track_open_orbital_finance_i", "PublicTrackSnapshot preserves clickable card-track identity and actions")
	_expect(_action_list_has_id(public_track_actions, "track_select_42") and _action_list_has_id(public_track_actions, "track_intel_42") and _action_list_has_id(public_track_deep_links, "track_intel_42") and _action_list_has_id(public_track_deep_links, "track_open_orbital_finance_i"), "PublicTrackSnapshot keeps track actions and intel/detail links as data-only UI commands")
	var planet_ui: Dictionary = planet.to_ui_dictionary()
	var planet_left: Dictionary = planet_ui.get("left_rail", {}) if planet_ui.get("left_rail", {}) is Dictionary else {}
	var planet_right: Dictionary = planet_ui.get("right_rail", {}) if planet_ui.get("right_rail", {}) is Dictionary else {}
	var planet_left_entries: Array = planet_left.get("entries", []) if planet_left.get("entries", []) is Array else []
	var planet_right_entries: Array = planet_right.get("entries", []) if planet_right.get("entries", []) is Array else []
	_expect(planet_left.get("title") == "地表情报" and planet_left_entries.size() == 1 and planet_left_entries[0].get("label") == "星区", "PlanetBoardSnapshot normalizes public surface rail entries")
	_expect(planet_right.get("title") == "外围压力" and planet_right_entries.size() == 1 and planet_right_entries[0].get("label") == "怪兽", "PlanetBoardSnapshot normalizes outer-pressure rail entries")
	_expect(table.to_ui_dictionary().has("right_inspector"), "TableSnapshot creates right-inspector UI context")
	_expect(table.to_ui_dictionary().get("card_track", []).size() == 1 and table.to_ui_dictionary().get("card_track", [])[0].get("state") == "当前", "TableSnapshot routes public track entries through PublicTrackSnapshot")
	var table_planet: Dictionary = table.to_ui_dictionary().get("planet", {}) if table.to_ui_dictionary().get("planet", {}) is Dictionary else {}
	var table_left_rail: Dictionary = table_planet.get("left_rail", {}) if table_planet.get("left_rail", {}) is Dictionary else {}
	var table_left_entries: Array = table_left_rail.get("entries", []) if table_left_rail.get("entries", []) is Array else []
	_expect(table_left_rail.get("title") == "地表情报" and table_left_entries.size() == 1 and table_left_entries[0].get("value") == "8区", "TableSnapshot routes planet state through PlanetBoardSnapshot")
	_expect(not _variant_contains_callable(table.to_ui_dictionary()), "TableSnapshot output stays data-only without Callable rule handles")
	_expect(not _variant_contains_callable(card_browser_ui), "CardCodexBrowserSnapshot output stays data-only without Callable rule handles")
	_expect(not _variant_contains_callable(card_detail_ui), "CardCodexDetailSnapshot output stays data-only without Callable rule handles")
	_expect(table.to_ui_dictionary().get("top_bar", {}).get("identity") == "赤港财团", "TableSnapshot derives top-bar state from player-board state")


func _check_menu_overlay_shell_component() -> void:
	var packed := load("res://scenes/ui/MenuOverlay.tscn") as PackedScene
	_expect(packed != null, "MenuOverlay scene loads for shell-component checks")
	if packed == null:
		return
	var overlay := packed.instantiate() as Control
	root.add_child(overlay)
	await process_frame
	_expect(overlay.has_method("present_menu_shell"), "MenuOverlay owns menu-shell rendering")
	_expect(overlay.has_method("hide_global_navigation"), "MenuOverlay owns global navigation hiding")
	_expect(overlay.has_method("set_catalog_navigation"), "MenuOverlay owns catalog navigation state")
	_expect(overlay.has_signal("continue_requested") and overlay.has_signal("main_menu_requested") and overlay.has_signal("catalog_step_requested") and overlay.has_signal("catalog_back_requested"), "MenuOverlay exposes shell navigation signals")
	var preview_box := overlay.find_child("MenuPreviewBox", true, false) as VBoxContainer
	var dummy := Label.new()
	dummy.text = "stale preview"
	preview_box.add_child(dummy)
	overlay.call("present_menu_shell", {
		"title": "Root table",
		"body": "",
		"context": "hidden context",
		"context_visible": false,
		"hint": "hidden hint",
		"hint_visible": false,
		"back_visible": false,
		"nav_visible": false,
		"root_table_menu": true,
		"viewport_size": Vector2(1280, 720),
	})
	await process_frame
	var title_label := overlay.find_child("MenuTitleLabel", true, false) as Label
	var context_label := overlay.find_child("MenuContextLabel", true, false) as Label
	var hint_panel := overlay.find_child("MenuInteractionHintPanel", true, false) as PanelContainer
	var nav_row := overlay.find_child("MenuNavRow", true, false) as HBoxContainer
	var surface_panel := overlay.find_child("MenuSurfacePanel", true, false) as PanelContainer
	_expect(overlay.visible and title_label != null and title_label.text == "Root table", "MenuOverlay presents root shell title")
	_expect(context_label != null and not context_label.visible and hint_panel != null and not hint_panel.visible and nav_row != null and not nav_row.visible, "MenuOverlay hides breadcrumb, hint, and global nav on root table menus")
	_expect(surface_panel != null and surface_panel.anchor_left == 0.0 and surface_panel.anchor_right == 1.0 and surface_panel.anchor_top == 0.0 and surface_panel.anchor_bottom == 1.0, "MenuOverlay presents root table menus as a full-screen lobby instead of a modal card")
	_expect(preview_box != null and preview_box.get_child_count() == 0 and not preview_box.visible, "MenuOverlay clears stale preview content when a shell opens")
	overlay.call("present_menu_shell", {
		"title": "Card codex",
		"body": "Scan the card.",
		"context": "Codex page",
		"hint": "Hover for preview",
		"continue_visible": true,
		"back_visible": true,
		"nav_visible": true,
		"viewport_size": Vector2(1600, 960),
	})
	await process_frame
	var body_label := overlay.find_child("MenuBodyLabel", true, false) as Label
	_expect(context_label != null and context_label.visible and hint_panel != null and hint_panel.visible and body_label != null and body_label.text == "Scan the card.", "MenuOverlay presents catalog shell context and body")
	overlay.call("set_catalog_navigation", {"prev_visible": true, "next_visible": true, "back_visible": true, "back_text": "Back to thumbnails"})
	await process_frame
	var catalog_nav_row := overlay.find_child("MenuCatalogNavRow", true, false) as HBoxContainer
	var catalog_back_button := overlay.find_child("MenuBestiaryBackButton", true, false) as Button
	_expect(catalog_nav_row != null and catalog_nav_row.visible and catalog_back_button != null and catalog_back_button.text == "Back to thumbnails", "MenuOverlay owns local catalog navigation buttons")
	var continue_button := overlay.find_child("MenuContinueButton", true, false) as Button
	var back_button := overlay.find_child("MenuBackButton", true, false) as Button
	var signal_flags := {
		"continue": false,
		"back": false,
		"catalog_back": false,
	}
	var catalog_steps: Array[int] = []
	overlay.connect("continue_requested", func() -> void:
		signal_flags["continue"] = true
	)
	overlay.connect("main_menu_requested", func() -> void:
		signal_flags["back"] = true
	)
	overlay.connect("catalog_step_requested", func(delta: int) -> void:
		catalog_steps.append(delta)
	)
	overlay.connect("catalog_back_requested", func() -> void:
		signal_flags["catalog_back"] = true
	)
	var catalog_prev_button := overlay.find_child("MenuBestiaryPrevButton", true, false) as Button
	var catalog_next_button := overlay.find_child("MenuBestiaryNextButton", true, false) as Button
	if continue_button != null:
		continue_button.emit_signal("pressed")
	if back_button != null:
		back_button.emit_signal("pressed")
	if catalog_prev_button != null:
		catalog_prev_button.emit_signal("pressed")
	if catalog_next_button != null:
		catalog_next_button.emit_signal("pressed")
	if catalog_back_button != null:
		catalog_back_button.emit_signal("pressed")
	await process_frame
	_expect(bool(signal_flags.get("continue", false)), "MenuOverlay emits continue_requested from the continue button")
	_expect(bool(signal_flags.get("back", false)), "MenuOverlay emits main_menu_requested from the back button")
	_expect(bool(signal_flags.get("catalog_back", false)), "MenuOverlay emits catalog_back_requested from the local catalog back button")
	_expect(catalog_steps.size() == 2 and catalog_steps[0] == -1 and catalog_steps[1] == 1, "MenuOverlay emits previous/next catalog step signals")
	overlay.call("hide_global_navigation")
	await process_frame
	_expect(continue_button != null and not continue_button.visible and back_button != null and not back_button.visible and nav_row != null and not nav_row.visible, "MenuOverlay hides global navigation without touching local catalog navigation")
	root.remove_child(overlay)
	overlay.queue_free()


func _check_tutorial_quick_start_board_component() -> void:
	var packed := load("res://scenes/ui/TutorialQuickStartBoard.tscn") as PackedScene
	_expect(packed != null, "TutorialQuickStartBoard scene loads for tutorial checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_board"), "TutorialQuickStartBoard owns quick-start snapshot rendering")
	board.call("set_board", {
		"title": "试玩速成板",
		"step_columns": 4,
		"trap_columns": 3,
		"chips": [
			{"text": "第一局", "accent": Color("#bfdbfe"), "tooltip": "先完成核心动作。"},
			{"text": "目标钱最多", "accent": Color("#fef3c7"), "tooltip": "终局按钱排名。"},
			{"text": "细则进规则", "accent": Color("#c4b5fd"), "tooltip": "完整解释在规则页。"},
		],
		"steps": [
			{"title": "1｜首召怪兽", "body": "选一个区域，打出起始I级怪兽。", "meta": "怪兽落地后，附近区域才是购牌锚点。", "accent": Color("#fb7185")},
			{"title": "2｜建第一城", "body": "找陆地，花钱城市化。", "meta": "城市会产生GDP/min。", "accent": Color("#4ade80")},
			{"title": "3｜看区域牌架", "body": "双击区域看卡牌。", "meta": "可看不等于可买。", "accent": Color("#38bdf8")},
			{"title": "4｜买第一张牌", "body": "买牌花钱；重复牌自动升级。", "meta": "满手会私下弃旧。", "accent": Color("#facc15")},
			{"title": "5｜打匿名牌", "body": "看手牌状态筹码。", "meta": "出牌者匿名。", "accent": Color("#c084fc")},
			{"title": "6｜读公共牌轨", "body": "顶部牌槽记录历史。", "meta": "可押钱猜牌主。", "accent": Color("#f472b6")},
			{"title": "7｜看经济/情报", "body": "经济看钱从哪里来。", "meta": "靠公开结果推理。", "accent": Color("#2dd4bf")},
			{"title": "8｜终局冲刺", "body": "有人达标后倒计时。", "meta": "结束按钱排名。", "accent": Color("#fb923c")},
		],
		"traps": [
			{"title": "买不了牌", "body": "先确认场上有怪兽和牌架位置。", "accent": Color("#fb7185")},
			{"title": "牌打不出", "body": "看商品流动、目标、选区、现金和队列。", "accent": Color("#facc15")},
			{"title": "看不懂谁领先", "body": "打开局势记分板。", "accent": Color("#38bdf8")},
			{"title": "不知道查哪里", "body": "打开情报侦探板。", "accent": Color("#c084fc")},
		],
		"footer": "完整细则进游戏规则；这一页只帮你把第一局跑起来。",
		"accent": Color("#38bdf8"),
	})
	await process_frame
	_expect(String(board.name) == "TutorialQuickStartPanel", "TutorialQuickStartBoard keeps the quick-start panel root")
	_expect(board.find_child("TutorialQuickStartHeader", true, false) != null and board.find_child("TutorialQuickStartChip", true, false) != null, "TutorialQuickStartBoard renders header chips")
	_expect(board.find_child("TutorialQuickStartStepGrid", true, false) != null and board.find_child("TutorialQuickStartStepCard", true, false) != null and board.find_child("TutorialQuickStartStepMeta", true, false) != null, "TutorialQuickStartBoard renders step cards")
	_expect(board.find_child("TutorialQuickStartTrapGrid", true, false) != null and board.find_child("TutorialQuickStartTrapCard", true, false) != null and board.find_child("TutorialQuickStartTrapCardBody", true, false) != null, "TutorialQuickStartBoard renders trap cards")
	_expect(board.find_child("TutorialQuickStartFooterHint", true, false) != null, "TutorialQuickStartBoard keeps long rules as a footer pointer instead of page prose")
	root.remove_child(board)
	board.queue_free()


func _check_rules_quick_reference_board_component() -> void:
	var packed := load("res://scenes/ui/RulesQuickReferenceBoard.tscn") as PackedScene
	_expect(packed != null, "RulesQuickReferenceBoard scene loads for rules checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_board"), "RulesQuickReferenceBoard owns rules snapshot rendering")
	board.call("set_board", {
		"title": "规则速查板",
		"kpi_columns": 4,
		"module_columns": 4,
		"chips": [
			{"text": "目标钱最多", "accent": Color("#fef3c7"), "tooltip": "胜利目标"},
			{"text": "主桌不背规则", "accent": Color("#93c5fd"), "tooltip": "长规则不常驻主桌"},
			{"text": "隐私靠推理", "accent": Color("#c4b5fd"), "tooltip": "隐藏对手私密信息"},
		],
		"kpis": [
			{"title": "胜利目标", "body": "最后钱最多。", "meta": "清算都会变成钱。", "accent": Color("#fef3c7")},
			{"title": "第一轮顺序", "body": "首召 → 建城 → 买牌 → 出牌。", "meta": "先跑起来。", "accent": Color("#38bdf8")},
			{"title": "信息边界", "body": "出牌公开，牌主匿名。", "meta": "靠公开线索推理。", "accent": Color("#c084fc")},
			{"title": "结算节奏", "body": "达标后终局沙漏。", "meta": "领先护城，落后压制。", "accent": Color("#fb923c")},
		],
		"modules": [
			{"title": "◆ 首召怪兽", "body": "先打一张I级怪兽牌。", "meta": "附近打开购牌来源。", "accent": Color("#fb7185")},
			{"title": "▣ 建城赚钱", "body": "陆地城市化。", "meta": "GDP/min按秒进账。", "accent": Color("#4ade80")},
			{"title": "＋ 区域牌架", "body": "双击区域看牌。", "meta": "开架时锁定资格。", "accent": Color("#38bdf8")},
			{"title": "◎ 匿名出牌", "body": "卡牌公开，牌主匿名。", "meta": "商品流动是门槛。", "accent": Color("#c084fc")},
			{"title": "¥ 竞价/猜牌主", "body": "多人出牌先报价。", "meta": "公共牌轨可猜牌主。", "accent": Color("#facc15")},
			{"title": "♠ 怪兽赌局", "body": "怪兽遭遇冻结时间。", "meta": "全员公开下注。", "accent": Color("#fb923c")},
			{"title": "⇄ 合约", "body": "先点供给区和需求区。", "meta": "目标业主签或拒。", "accent": Color("#2dd4bf")},
			{"title": "☄ 天气/现金流", "body": "天气影响生产交通消费。", "meta": "改变GDP/min。", "accent": Color("#93c5fd")},
		],
		"footer": "完整细则在本页正文；主桌只保留当前能做什么和为什么不能做。",
		"accent": Color("#93c5fd"),
	})
	await process_frame
	_expect(String(board.name) == "RulesQuickReferencePanel", "RulesQuickReferenceBoard keeps the rules panel root")
	_expect(board.find_child("RulesQuickReferenceHeader", true, false) != null and board.find_child("RulesQuickReferenceChip", true, false) != null, "RulesQuickReferenceBoard renders header chips")
	_expect(board.find_child("RulesQuickReferenceKpiGrid", true, false) != null and board.find_child("RulesQuickReferenceKpiCard", true, false) != null and board.find_child("RulesQuickReferenceKpiMeta", true, false) != null, "RulesQuickReferenceBoard renders KPI cards")
	_expect(board.find_child("RulesQuickReferenceModuleGrid", true, false) != null and board.find_child("RulesQuickReferenceModuleCard", true, false) != null and board.find_child("RulesQuickReferenceModuleMeta", true, false) != null, "RulesQuickReferenceBoard renders module cards")
	_expect(board.find_child("RulesQuickReferenceFooterHint", true, false) != null, "RulesQuickReferenceBoard points long rules back to the rules page instead of the main table")
	root.remove_child(board)
	board.queue_free()


func _check_role_codex_identity_board_component() -> void:
	var packed := load("res://scenes/ui/RoleCodexIdentityBoard.tscn") as PackedScene
	_expect(packed != null, "RoleCodexIdentityBoard scene loads for role codex checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_role"), "RoleCodexIdentityBoard owns role snapshot rendering")
	board.call("set_role", {
		"title": "织网会计｜第1/4张",
		"subtitle": "账簿星人｜商品经营 / 情报推理",
		"kpi_columns": 4,
		"route_columns": 3,
		"face": {
			"name": "织网会计",
			"cost": "R",
			"effect": "特征：低调经营\n被动：商品城市额外现金\n角色资料：公开身份；开局怪兽独立选择。",
			"type": "角色卡 / 账簿星人",
			"rank": "账簿星人",
			"accent": Color("#c084fc"),
			"minimum_width": 210.0,
			"minimum_height": 250.0,
		},
		"chips": [
			{"text": "公开角色", "accent": Color("#fde68a"), "tooltip": "角色身份公开。"},
			{"text": "首召独立", "accent": Color("#bfdbfe"), "tooltip": "怪兽另选。"},
			{"text": "商品经营", "accent": Color("#c084fc"), "tooltip": "主要牌路。"},
		],
		"kpis": [
			{"title": "经济", "value": "商品城市+¥80/min", "meta": "现金/商品/购牌收益", "accent": Color("#bbf7d0")},
			{"title": "情报", "value": "查城市2次", "meta": "侦测、追溯和竞猜优势", "accent": Color("#c4b5fd")},
			{"title": "控制", "value": "标准购牌/合约", "meta": "购牌范围、合约、单位或反制", "accent": Color("#93c5fd")},
			{"title": "开局", "value": "优先找商品相关区域建城", "meta": "第一局建议动作", "accent": Color("#facc15")},
		],
		"routes": [
			{"title": "被动能力", "body": "商品城市产生额外现金。", "accent": Color("#fde68a")},
			{"title": "角色特征", "body": "擅长低调累计现金。", "accent": Color("#c084fc")},
			{"title": "信息边界", "body": "角色公开；手牌和现金仍靠线索推理。", "accent": Color("#f0abfc")},
			{"title": "开局打法", "body": "先建城，再围绕商品路线补牌。", "accent": Color("#4ade80")},
			{"title": "选择提醒", "body": "选角色不选怪兽。", "accent": Color("#38bdf8")},
			{"title": "风味", "body": "用账簿藏住真正的收益点。", "accent": Color("#fb923c")},
		],
		"accent": Color("#c084fc"),
	})
	await process_frame
	_expect(String(board.name) == "RoleCodexIdentityBoardPanel", "RoleCodexIdentityBoard keeps the role identity panel root")
	_expect(board.find_child("RoleCodexIdentityHeader", true, false) != null and board.find_child("RoleCodexSceneCardFace", true, false) != null, "RoleCodexIdentityBoard renders an embedded scene-owned CardFace")
	_expect(board.find_child("RoleCodexIdentityChipRail", true, false) != null and board.find_child("RoleCodexIdentityChip", true, false) != null, "RoleCodexIdentityBoard renders public identity chips")
	_expect(board.find_child("RoleCodexAbilityKpiGrid", true, false) != null and board.find_child("RoleCodexAbilityKpiCard", true, false) != null and board.find_child("RoleCodexAbilityKpiValue", true, false) != null, "RoleCodexIdentityBoard renders ability KPI cards")
	_expect(board.find_child("RoleCodexRouteCardGrid", true, false) != null and board.find_child("RoleCodexRouteCard", true, false) != null and board.find_child("RoleCodexRouteCardBody", true, false) != null, "RoleCodexIdentityBoard renders route cards")
	root.remove_child(board)
	board.queue_free()


func _check_compendium_hub_board_component() -> void:
	var packed := load("res://scenes/ui/CompendiumHubBoard.tscn") as PackedScene
	_expect(packed != null, "CompendiumHubBoard scene loads for compendium checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_hub") and board.has_signal("action_requested"), "CompendiumHubBoard owns hub snapshot rendering and action signals")
	var action_ids: Array[String] = []
	board.connect("action_requested", func(action_id: String) -> void:
		action_ids.append(action_id)
	)
	board.call("set_hub", {
		"title": "资料大厅",
		"kpi_columns": 3,
		"action_columns": 3,
		"chips": [
			{"text": "角色/卡牌/商品", "accent": Color("#fce7f3"), "tooltip": "资料分支"},
			{"text": "区域/怪兽生态", "accent": Color("#bfdbfe"), "tooltip": "地图和单位"},
			{"text": "主桌不放长资料", "accent": Color("#fde68a"), "tooltip": "长资料只在 Codex"},
		],
		"kpis": [
			{"title": "资料边界", "body": "怪兽牌属于卡牌图鉴；生态档案看单位行为。", "meta": "卡牌/单位分开读。", "accent": Color("#fb7185")},
			{"title": "隐私边界", "body": "角色公开，手牌和现金靠线索推理。", "meta": "不扫描对手私牌。", "accent": Color("#c084fc")},
			{"title": "返回路径", "body": "子图鉴回到资料大厅。", "meta": "不影响牌桌。", "accent": Color("#38bdf8")},
		],
		"actions": [
			{"id": "role", "title": "角色图鉴", "body": "查看角色卡。", "accent": Color("#c084fc")},
			{"id": "monster", "title": "怪兽生态档案", "body": "查看怪兽行为。", "accent": Color("#fb7185")},
			{"id": "card", "title": "卡牌图鉴", "body": "查看卡面。", "accent": Color("#f472b6")},
			{"id": "product", "title": "商品图鉴", "body": "查看商品市场。", "accent": Color("#facc15")},
			{"id": "region", "title": "区域图鉴", "body": "查看区域事实。", "accent": Color("#38bdf8")},
			{"id": "main", "title": "返回主菜单", "body": "回到大厅。", "accent": Color("#67e8f9")},
		],
		"footer": "资料大厅只承载长资料；主桌继续只保留当前行动和短解释。",
		"accent": Color("#f472b6"),
	})
	await process_frame
	_expect(String(board.name) == "CompendiumHubBoardPanel", "CompendiumHubBoard keeps the hub panel root")
	_expect(board.find_child("CompendiumHubHeader", true, false) != null and board.find_child("CompendiumHubChip", true, false) != null, "CompendiumHubBoard renders header chips")
	_expect(board.find_child("CompendiumHubKpiGrid", true, false) != null and board.find_child("CompendiumHubKpiCard", true, false) != null and board.find_child("CompendiumHubKpiMeta", true, false) != null, "CompendiumHubBoard renders boundary KPI cards")
	_expect(board.find_child("CompendiumHubActionGrid", true, false) != null and board.find_child("CompendiumHubActionButton", true, false) != null, "CompendiumHubBoard renders branch action buttons")
	var role_button := board.find_child("CompendiumHubActionButton", true, false) as Button
	if role_button != null:
		role_button.emit_signal("pressed")
	await process_frame
	_expect(action_ids.size() == 1 and action_ids[0] == "role", "CompendiumHubBoard emits action ids from branch buttons")
	root.remove_child(board)
	board.queue_free()


func _check_card_codex_browser_component() -> void:
	var packed := load("res://scenes/ui/CardCodexBrowser.tscn") as PackedScene
	_expect(packed != null, "CardCodexBrowser scene loads for thumbnail-browser checks")
	if packed == null:
		return
	var browser := packed.instantiate() as Control
	root.add_child(browser)
	await process_frame
	_expect(browser.has_method("set_browser") and browser.has_method("set_preview"), "CardCodexBrowser owns snapshot rendering methods")
	_expect(browser.has_signal("filter_selected") and browser.has_signal("page_step_requested") and browser.has_signal("card_preview_requested") and browser.has_signal("card_detail_requested"), "CardCodexBrowser exposes filter, paging, preview, and detail signals")
	browser.call("set_browser", {
		"legend": "牌型筛选｜图标：◆怪兽 ◇商品",
		"legend_tooltip": "点筹码只看这一类牌。",
		"columns": 2,
		"previous_text": "缩略图上一页",
		"next_text": "缩略图下一页",
		"page_text": "第1/2页｜2张卡｜本页1-2",
		"filters": [
			{"id": "monster", "text": "◆怪兽·4", "active": true, "accent": Color("#f97316")},
			{"id": "weather", "text": "☄天气·2", "active": false, "accent": Color("#38bdf8")},
		],
		"cards": [
			{
				"card_name": "phase_beast_i",
				"title": "◆ 怪兽｜I",
				"title_tooltip": "相位兽 I",
				"art_text": "相位兽\n怪兽",
				"kind": "monster",
				"chips": [
					{"text": "¥2", "tooltip": "费用", "fg": Color("#fef3c7"), "accent": Color("#f97316")},
					{"text": "邻区", "tooltip": "门槛", "fg": Color("#bae6fd"), "accent": Color("#38bdf8")},
				],
				"route": "压迫航线",
				"route_tooltip": "迫使玩家换区。",
				"effect": "邻区威胁上升",
				"effect_tooltip": "移动并制造压力。",
				"hint": "悬停预览｜双击详情",
				"tooltip": "完整卡牌说明",
				"accent": Color("#f97316"),
				"selected": true,
			},
		],
		"preview": {
			"title": "悬停预览：◆ 相位兽 I",
			"body": "路线：压迫｜邻区威胁\nI→IV：更远、更硬",
			"accent": Color("#f97316"),
		},
	})
	await process_frame
	_expect(browser.find_child("CardCodexCategoryRail", true, false) != null, "CardCodexBrowser keeps the category rail")
	_expect(browser.find_child("CardCodexCategoryChipRow", true, false) != null and browser.find_child("CardCodexCategoryChip", true, false) != null, "CardCodexBrowser renders category chips from snapshots")
	_expect(browser.find_child("CardCodexThumbnailGrid", true, false) != null and browser.find_child("CardCodexThumbnailChipRail", true, false) != null, "CardCodexBrowser renders thumbnail grid and chip rails")
	_expect(browser.find_child("CardCodexThumbnailRouteBand", true, false) != null and browser.find_child("CardCodexThumbnailEffectLine", true, false) != null, "CardCodexBrowser renders route and effect scan lines")
	_expect(browser.find_child("CardCodexHoverPreview", true, false) != null, "CardCodexBrowser renders the hover preview host")
	var signal_flags := {
		"filter": "",
		"preview": "",
		"detail": "",
	}
	var page_steps: Array[int] = []
	browser.connect("filter_selected", func(filter_id: String) -> void:
		signal_flags["filter"] = filter_id
	)
	browser.connect("page_step_requested", func(delta: int) -> void:
		page_steps.append(delta)
	)
	browser.connect("card_preview_requested", func(card_name: String) -> void:
		signal_flags["preview"] = card_name
	)
	browser.connect("card_detail_requested", func(card_name: String) -> void:
		signal_flags["detail"] = card_name
	)
	var filter_chip := browser.find_child("CardCodexCategoryChip", true, false) as Button
	var previous_button := browser.find_child("CardCodexThumbnailPreviousButton", true, false) as Button
	var next_button := browser.find_child("CardCodexThumbnailNextButton", true, false) as Button
	var card_panel := browser.find_child("CardCodexThumbnailCard", true, false) as Control
	if filter_chip != null:
		filter_chip.emit_signal("pressed")
	if previous_button != null:
		previous_button.emit_signal("pressed")
	if next_button != null:
		next_button.emit_signal("pressed")
	if card_panel != null:
		card_panel.emit_signal("mouse_entered")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.double_click = true
		card_panel.gui_input.emit(event)
	await process_frame
	_expect(signal_flags.get("filter", "") == "monster", "CardCodexBrowser emits filter selection from category chips")
	_expect(page_steps.size() == 2 and page_steps[0] == -1 and page_steps[1] == 1, "CardCodexBrowser emits previous/next page requests")
	_expect(signal_flags.get("preview", "") == "phase_beast_i", "CardCodexBrowser emits card hover preview requests")
	_expect(signal_flags.get("detail", "") == "phase_beast_i", "CardCodexBrowser emits double-click detail requests")
	browser.call("set_preview", {"title": "悬停预览：◇ 商品", "body": "短预览", "accent": Color("#22c55e")})
	await process_frame
	var preview_title := browser.find_child("CardCodexHoverPreviewTitle", true, false) as Label
	_expect(preview_title != null and preview_title.text.contains("商品"), "CardCodexBrowser can refresh preview without rebuilding the menu shell")
	root.remove_child(browser)
	browser.queue_free()


func _check_card_codex_detail_component() -> void:
	var packed := load("res://scenes/ui/CardCodexDetail.tscn") as PackedScene
	_expect(packed != null, "CardCodexDetail scene loads for detail-page checks")
	if packed == null:
		return
	var detail := packed.instantiate() as Control
	root.add_child(detail)
	await process_frame
	_expect(detail.has_method("set_detail"), "CardCodexDetail owns detail snapshot rendering")
	detail.call("set_detail", {
		"accent": Color("#f97316"),
		"tooltip": "完整卡牌公开说明",
		"face_note": "重复入手→升级；价格看I级。",
		"card_face": {
			"name": "◆ 相位兽 I",
			"cost": "¥2",
			"effect": "邻区威胁上升。",
			"type": "怪兽路线",
			"rank": "I",
			"accent": Color("#f97316"),
			"minimum_width": 180.0,
			"minimum_height": 230.0,
		},
		"summary": {
			"title": "扫牌顺序",
			"header_chips": [
				{"text": "◆怪兽", "accent": Color("#f97316"), "tooltip": "卡牌类型"},
				{"text": "怪兽路线", "accent": Color("#c084fc"), "tooltip": "策略路线"},
			],
			"chips": [
				{"text": "¥2", "tooltip": "费用", "fg": Color("#fef3c7"), "accent": Color("#f97316")},
				{"text": "目标", "tooltip": "目标类型", "fg": Color("#bae6fd"), "accent": Color("#38bdf8")},
			],
			"effect": "速读：压迫邻区｜热度上升",
			"effect_tooltip": "完整效果",
			"read_order": "读法：费用 → 门槛 → 目标 → 去向 → 效果 → I-IV升级",
			"accent": Color("#f97316"),
		},
		"tactical": {
			"title": "牌桌用途｜先看这三格",
			"entries": [
				{"title": "何时拿", "body": "想铺怪兽压力时拿。", "accent": Color("#f97316"), "tooltip": "拿牌时机"},
				{"title": "怎么配", "body": "配合诱导与赌局。", "accent": Color("#38bdf8"), "tooltip": "配合路线"},
				{"title": "会暴露", "body": "目标怪兽公开。", "accent": Color("#f472b6"), "tooltip": "公开线索"},
			],
			"accent": Color("#f97316"),
		},
		"facts": [
			{"title": "◎ 牌面定位", "body": "地图压力", "meta": "◆怪兽｜路线", "accent": Color("#f97316")},
			{"title": "¥ 费用与门槛", "body": "购买 ¥2", "meta": "目标:怪兽", "accent": Color("#facc15")},
			{"title": "✦ 核心效果", "body": "移动并制造压力。", "meta": "一次性牌", "accent": Color("#fb7185")},
			{"title": "◈ 关键数值", "body": "热度+2", "meta": "看收益与风险", "accent": Color("#38bdf8")},
		],
		"upgrade_title": "I→IV 强化",
		"upgrades": [
			{"roman": "I", "price": "¥2", "band": "轻量", "body": "热度+2", "accent": Color("#f97316")},
			{"roman": "II", "price": "¥2", "band": "标准", "body": "热度+3", "accent": Color("#fb923c")},
		],
		"resolution": {"title": "◇ 结算演出", "body": "所有玩家看见卡面。", "meta": "出牌者匿名。", "accent": Color("#fb7185")},
	})
	await process_frame
	_expect(detail.find_child("CardCodexTcgDetailLayout", true, false) != null, "CardCodexDetail keeps the TCG detail layout")
	_expect(detail.find_child("CardCodexTcgFaceColumn", true, false) != null and detail.find_child("CardCodexSceneCardFace", true, false) != null, "CardCodexDetail renders a scene-owned CardFace")
	_expect(detail.find_child("CardCodexTcgReadColumn", true, false) != null and detail.find_child("CardCodexTcgSummaryPanel", true, false) != null, "CardCodexDetail renders the scan-first summary panel")
	_expect(detail.find_child("CardCodexTcgSummaryChipRail", true, false) != null and detail.find_child("CardCodexTcgSummaryChip", true, false) != null, "CardCodexDetail renders summary chips")
	_expect(detail.find_child("CardCodexTacticalStrip", true, false) != null and detail.find_child("CardCodexTacticalGrid", true, false) != null and detail.find_child("CardCodexTacticalCard", true, false) != null, "CardCodexDetail renders tactical table-use cards")
	_expect(detail.find_child("CardCodexTcgFactGrid", true, false) != null and detail.find_child("CardCodexTcgFactCard", true, false) != null, "CardCodexDetail renders fact cards")
	_expect(detail.find_child("CardCodexUpgradeLadder", true, false) != null and detail.find_child("CardCodexUpgradeStepCard", true, false) != null and detail.find_child("CardCodexUpgradeRomanLevel", true, false) != null, "CardCodexDetail renders roman-level upgrade cards")
	_expect(detail.find_child("CardCodexResolutionInfoCard", true, false) != null, "CardCodexDetail renders the public resolution note")
	root.remove_child(detail)
	detail.queue_free()


func _check_region_codex_detail_component() -> void:
	var packed := load("res://scenes/ui/RegionCodexDetail.tscn") as PackedScene
	_expect(packed != null, "RegionCodexDetail scene loads for region-detail checks")
	if packed == null:
		return
	var detail := packed.instantiate() as Control
	root.add_child(detail)
	await process_frame
	_expect(detail.has_method("set_region"), "RegionCodexDetail owns region snapshot rendering")
	detail.call("set_region", {
		"icon": "▣",
		"title": "雾港区｜第2/12区",
		"subtitle": "海港｜商品贸易｜城市Lv.2｜GDP/min 18",
		"chips": [
			{"text": "HP 5/8", "fg": Color("#bbf7d0"), "accent": Color("#bbf7d0"), "tooltip": "区域耐久"},
			{"text": "热度 3", "fg": Color("#fef3c7"), "accent": Color("#fef3c7"), "tooltip": "公开热度"},
			{"text": "当前选中", "fg": Color("#fde68a"), "accent": Color("#fde68a"), "tooltip": "当前选区"},
		],
		"kpis": [
			{"title": "城市", "value": "城市Lv.2｜GDP/min 18", "meta": "生产带来收入", "accent": Color("#facc15")},
			{"title": "供给", "value": "海雾果 ¥120", "meta": "生产/商品价格线索", "accent": Color("#4ade80")},
			{"title": "需求", "value": "轨迹墨水 ¥180", "meta": "需求会抬高商品价格", "accent": Color("#fb7185")},
			{"title": "天气", "value": "雾雨", "meta": "影响产/交/消", "accent": Color("#38bdf8")},
		],
		"clues": [
			{"title": "商路", "body": "途经/使用 2条", "tooltip": "连到荒原与港口", "accent": Color("#93c5fd")},
			{"title": "牌架", "body": "金融牌、合约牌、天气牌", "tooltip": "双击地图区域可打开牌架", "accent": Color("#a78bfa")},
			{"title": "怪兽吸引", "body": "怪1·相位兽 盯上高热度", "tooltip": "怪兽按公开压力选择目标", "accent": Color("#fb923c")},
			{"title": "公开线索", "body": "最近有人加固城市", "tooltip": "可见证据，不等于真实业主", "accent": Color("#f0abfc")},
			{"title": "邻接", "body": "东港、北湾", "tooltip": "移动和购牌依赖邻接", "accent": Color("#67e8f9")},
			{"title": "读法", "body": "先看城市GDP，再看供需/商路/怪兽。", "tooltip": "不提前揭示他人隐私", "accent": Color("#fde68a")},
		],
		"accent": Color("#38bdf8"),
	})
	await process_frame
	_expect(String(detail.name) == "RegionCodexTileBoardPanel", "RegionCodexDetail keeps the tile board panel")
	_expect(detail.find_child("RegionCodexTileHeader", true, false) != null and detail.find_child("RegionCodexTileIcon", true, false) != null, "RegionCodexDetail renders header and terrain icon")
	_expect(detail.find_child("RegionCodexTileChipRail", true, false) != null and detail.find_child("RegionCodexTileChip", true, false) != null, "RegionCodexDetail renders public chips")
	_expect(detail.find_child("RegionCodexTileKpiGrid", true, false) != null and detail.find_child("RegionCodexTileKpiCard", true, false) != null and detail.find_child("RegionCodexTileKpiValue", true, false) != null, "RegionCodexDetail renders KPI cards")
	_expect(detail.find_child("RegionCodexActionClueGrid", true, false) != null and detail.find_child("RegionCodexClueCard", true, false) != null and detail.find_child("RegionCodexClueBody", true, false) != null, "RegionCodexDetail renders action/clue cards")
	root.remove_child(detail)
	detail.queue_free()


func _check_product_codex_detail_component() -> void:
	var packed := load("res://scenes/ui/ProductCodexDetail.tscn") as PackedScene
	_expect(packed != null, "ProductCodexDetail scene loads for product-detail checks")
	if packed == null:
		return
	var detail := packed.instantiate() as Control
	root.add_child(detail)
	await process_frame
	_expect(detail.has_method("set_product"), "ProductCodexDetail owns product snapshot rendering")
	detail.call("set_product", {
		"title": "活体芯片｜情报商业线",
		"subtitle": "科技商品｜地形:城市｜观察供需、合约、仓储和怪兽偏好。",
		"badge": {
			"name": "活体芯片",
			"glyph": "◇",
			"profile": "科技商品｜情报商业线",
			"terrain": "地形:城市",
			"price": "¥180｜基准¥150｜上涨",
			"meter": "供2 需4 断1 波3",
			"weather": "星尘潮提高科技商品流通。",
			"use": "连接情报、期货、仓储和城市GDP。",
			"accent": Color("#22c55e"),
			"secondary": Color("#bae6fd"),
		},
		"chips": [
			{"text": "¥180", "fg": Color("#bbf7d0"), "accent": Color("#bbf7d0"), "tooltip": "当前市场价"},
			{"text": "供2", "fg": Color("#4ade80"), "accent": Color("#4ade80"), "tooltip": "公开供给"},
			{"text": "需4", "fg": Color("#fb7185"), "accent": Color("#fb7185"), "tooltip": "公开需求"},
		],
		"kpis": [
			{"title": "价格", "value": "¥180｜III", "meta": "近期:+20", "accent": Color("#bbf7d0")},
			{"title": "主策略", "value": "主策略:看涨42", "meta": "需求高于供给", "accent": Color("#facc15")},
			{"title": "天气", "value": "星尘潮", "meta": "天气会改写产/交/消", "accent": Color("#38bdf8")},
			{"title": "牌路", "value": "出牌追帧1", "meta": "相关卡牌入口", "accent": Color("#a78bfa")},
		],
		"strategies": [
			{"title": "策略用途", "body": "用作情报线与城市收益的桥。", "tooltip": "策略摘要", "accent": Color("#fde68a")},
			{"title": "期货/仓储", "body": "适合看涨和港仓囤货。", "tooltip": "仓储风险", "accent": Color("#f97316")},
			{"title": "怪兽偏好", "body": "部分怪兽会盯上芯片仓库。", "tooltip": "怪兽偏好", "accent": Color("#fb923c")},
			{"title": "地图供给", "body": "雾港区、轨道城", "tooltip": "本地供给区域", "accent": Color("#4ade80")},
			{"title": "地图需求", "body": "深空站、维修港", "tooltip": "本地需求区域", "accent": Color("#fb7185")},
			{"title": "城市线索", "body": "公开城市正在收购。", "tooltip": "城市线索", "accent": Color("#f0abfc")},
		],
		"accent": Color("#22c55e"),
		"secondary": Color("#bae6fd"),
	})
	await process_frame
	_expect(String(detail.name) == "ProductCodexMarketBoardPanel", "ProductCodexDetail keeps the market board panel")
	_expect(detail.find_child("ProductCodexMarketHeader", true, false) != null and detail.find_child("ProductCodexMarketBadge", true, false) != null, "ProductCodexDetail renders header and market badge")
	_expect(detail.find_child("ProductCodexMarketChipRail", true, false) != null and detail.find_child("ProductCodexMarketChip", true, false) != null, "ProductCodexDetail renders market chips")
	_expect(detail.find_child("ProductCodexMarketKpiGrid", true, false) != null and detail.find_child("ProductCodexMarketKpiCard", true, false) != null and detail.find_child("ProductCodexMarketKpiValue", true, false) != null, "ProductCodexDetail renders KPI cards")
	_expect(detail.find_child("ProductCodexStrategyGrid", true, false) != null and detail.find_child("ProductCodexStrategyCard", true, false) != null and detail.find_child("ProductCodexStrategyBody", true, false) != null, "ProductCodexDetail renders strategy cards")
	root.remove_child(detail)
	detail.queue_free()


func _check_bestiary_detail_component() -> void:
	var packed := load("res://scenes/ui/BestiaryDetail.tscn") as PackedScene
	_expect(packed != null, "BestiaryDetail scene loads for monster-detail checks")
	if packed == null:
		return
	var detail := packed.instantiate() as Control
	root.add_child(detail)
	await process_frame
	_expect(detail.has_method("set_monster"), "BestiaryDetail owns monster snapshot rendering")
	detail.call("set_monster", {
		"title": "相位兽｜怪兽单位档案",
		"subtitle": "会穿过城市边界的自动怪兽。",
		"tooltip": "怪兽详情",
		"art": {
			"name": "相位兽",
			"style": "会穿过城市边界的自动怪兽。",
			"hp": 12,
			"armor": 2,
			"move_text": "24m/s",
			"profile": {"accent": Color("#fb7185"), "secondary": Color("#bfdbfe"), "glyph": "相", "motif": "mirror_hunter", "subtitle": "星兽档案"},
		},
		"chips": [
			{"text": "HP12", "fg": Color("#fecdd3"), "accent": Color("#fecdd3"), "tooltip": "生命"},
			{"text": "甲2", "fg": Color("#bfdbfe"), "accent": Color("#bfdbfe"), "tooltip": "护甲"},
			{"text": "速24m/s", "fg": Color("#fdba74"), "accent": Color("#fdba74"), "tooltip": "速度"},
		],
		"kpis": [
			{"title": "生态位", "value": "飞行｜跨地形", "meta": "召唤:monster_zone｜移动24m/s", "accent": Color("#fb923c")},
			{"title": "资源与经济", "value": "活体芯片", "meta": "吸取1｜暂无经济钩子", "accent": Color("#4ade80")},
			{"title": "行动定位", "value": "机动、控制", "meta": "最高伤3｜射程120m", "accent": Color("#38bdf8")},
			{"title": "固定技能成长", "value": "I:1张 / II:2张", "meta": "IV概率:危险行动更容易出现", "accent": Color("#fde047")},
		],
		"action_title": "行动概率板｜I级/IV级｜开局/破坏后",
		"actions": [
			{
				"index": "01",
				"name": "相位突袭",
				"tags": "机动、伤害",
				"probability": "I 30%/40%｜IV 45%/55%",
				"probability_tooltip": "I开局30 / I破坏后40",
				"facts": "招式伤害3｜射程120m",
				"body": "贴近城市并制造公开压力。",
				"tooltip": "相位突袭",
				"accent": Color("#fb7185"),
			},
			{
				"index": "02",
				"name": "镜面拖拽",
				"tags": "控制、位移",
				"probability": "I 20%/25%｜IV 30%/36%",
				"probability_tooltip": "IV修正",
				"facts": "击退80m｜热度+4",
				"body": "把目标推向邻接区域。",
				"tooltip": "镜面拖拽",
				"accent": Color("#fda4af"),
			},
		],
		"accent": Color("#fb7185"),
	})
	await process_frame
	_expect(String(detail.name) == "BestiaryMonsterBoardPanel", "BestiaryDetail keeps the monster board panel")
	_expect(detail.find_child("BestiaryMonsterHeader", true, false) != null and detail.find_child("BestiaryMonsterArtView", true, false) != null, "BestiaryDetail renders header and monster art")
	_expect(detail.find_child("BestiaryMonsterChipRail", true, false) != null and detail.find_child("BestiaryMonsterChip", true, false) != null, "BestiaryDetail renders public monster chips")
	_expect(detail.find_child("BestiaryMonsterKpiGrid", true, false) != null and detail.find_child("BestiaryMonsterKpiCard", true, false) != null and detail.find_child("BestiaryMonsterKpiValue", true, false) != null, "BestiaryDetail renders KPI cards")
	_expect(detail.find_child("BestiaryMonsterActionGrid", true, false) != null and detail.find_child("BestiaryMonsterActionCard", true, false) != null and detail.find_child("BestiaryMonsterActionProbability", true, false) != null, "BestiaryDetail renders action probability cards")
	root.remove_child(detail)
	detail.queue_free()


func _check_economy_dashboard_component() -> void:
	var packed := load("res://scenes/ui/EconomyDashboard.tscn") as PackedScene
	_expect(packed != null, "EconomyDashboard scene loads for economy-dashboard checks")
	if packed == null:
		return
	var dashboard := packed.instantiate() as Control
	root.add_child(dashboard)
	await process_frame
	_expect(dashboard.has_method("set_dashboard"), "EconomyDashboard owns dashboard snapshot rendering")
	dashboard.call("set_dashboard", {
		"title": "经济仪表板",
		"title_tooltip": "先看现金流、商品、城市、线索四块；细节用悬停查看。",
		"kpi_columns": 4,
		"lane_columns": 3,
		"chips": [
			{"text": "刷新7", "accent": Color("#86efac"), "tooltip": "市场刷新"},
			{"text": "怪兽2", "accent": Color("#fb7185"), "tooltip": "怪兽风险"},
			{"text": "天气晴", "accent": Color("#38bdf8"), "tooltip": "天气影响"},
		],
		"kpis": [
			{"title": "GDP/min", "value": "220", "meta": "玩家1", "accent": Color("#4ade80"), "tooltip": "当前现金流"},
			{"title": "商品热度", "value": "活体芯片 ¥180", "meta": "价格/供需/趋势", "accent": Color("#facc15"), "tooltip": "商品热度"},
			{"title": "城市前景", "value": "雾港 +48", "meta": "收入/断路/业主视角", "accent": Color("#38bdf8"), "tooltip": "城市前景"},
			{"title": "公开线索", "value": "6", "meta": "卡牌/城市/怪兽", "accent": Color("#c084fc"), "tooltip": "公开证据"},
		],
		"lanes": [
			{"title": "商品热榜", "lines": ["活体芯片 ¥180｜供2/需5｜趋势+12"], "accent": Color("#facc15"), "tooltip": "热商品"},
			{"title": "低价机会", "lines": ["星露莓 ¥90｜供6/需1｜受压-8"], "accent": Color("#93c5fd"), "tooltip": "冷商品"},
			{"title": "城市现金流", "lines": ["雾港｜未知业主｜收入48｜断0"], "accent": Color("#4ade80"), "tooltip": "城市现金流"},
			{"title": "匿名余波", "lines": ["有人打出合约牌，目标城市收入跳变"], "accent": Color("#f472b6"), "tooltip": "匿名卡余波"},
			{"title": "怪兽/仓储风险", "lines": ["仓储城市被怪兽盯上"], "accent": Color("#fb7185"), "tooltip": "经济风险"},
			{"title": "下一步读法", "lines": ["热商品：扩需求、保运输、买涨。"], "accent": Color("#a78bfa"), "tooltip": "下一步"},
		],
		"accent": Color("#4ade80"),
	})
	await process_frame
	_expect(String(dashboard.name) == "EconomyDashboardPanel", "EconomyDashboard keeps the dashboard panel root")
	_expect(dashboard.find_child("EconomyDashboardHeader", true, false) != null and dashboard.find_child("EconomyDashboardChip", true, false) != null, "EconomyDashboard renders header chips")
	_expect(dashboard.find_child("EconomyDashboardKpiGrid", true, false) != null and dashboard.find_child("EconomyDashboardKpiCard", true, false) != null and dashboard.find_child("EconomyDashboardKpiValue", true, false) != null, "EconomyDashboard renders KPI cards")
	_expect(dashboard.find_child("EconomyDashboardLaneGrid", true, false) != null and dashboard.find_child("EconomyDashboardListCard", true, false) != null and dashboard.find_child("EconomyDashboardListLine", true, false) != null, "EconomyDashboard renders economy lane list cards")
	root.remove_child(dashboard)
	dashboard.queue_free()


func _check_intel_dossier_board_component() -> void:
	var packed := load("res://scenes/ui/IntelDossierBoard.tscn") as PackedScene
	_expect(packed != null, "IntelDossierBoard scene loads for intel-dossier checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_dossier"), "IntelDossierBoard owns dossier snapshot rendering")
	_expect(board.has_signal("action_requested"), "IntelDossierBoard exposes selected-card evidence-chain action signals")
	var emitted_dossier_actions: Array[String] = []
	if board.has_signal("action_requested"):
		board.connect("action_requested", func(action_id: String) -> void:
			emitted_dossier_actions.append(action_id)
		)
	board.call("set_dossier", {
		"title": "情报侦探板",
		"title_tooltip": "先扫线索类别，再决定标注城市、猜卡牌归属或跳到图鉴查证。",
		"kpi_columns": 4,
		"clue_columns": 3,
		"chips": [
			{"text": "终局揭晓", "accent": Color("#fef3c7"), "tooltip": "终局结算"},
			{"text": "即时竞猜¥40", "accent": Color("#c4b5fd"), "tooltip": "牌轨竞猜"},
			{"text": "不看对手现金", "accent": Color("#94a3b8"), "tooltip": "隐私保护"},
		],
		"kpis": [
			{"title": "城市标注", "value": "2/5", "meta": "全对+300｜全错-120", "accent": Color("#38bdf8"), "tooltip": "城市归属标注"},
			{"title": "待查城市", "value": "3", "meta": "优先看高GDP/仓储/断路", "accent": Color("#facc15"), "tooltip": "待查城市"},
			{"title": "牌轨牌", "value": "4", "meta": "归属/条件", "accent": Color("#f472b6"), "tooltip": "公开牌轨"},
			{"title": "公开资金线索", "value": "2", "meta": "怪兽受伤/仓储风险1", "accent": Color("#fb7185"), "tooltip": "公开线索"},
		],
		"actions": [
			{"id": "track_return_42", "label": "回到牌轨", "accent": Color("#38bdf8"), "tooltip": "回到主桌"},
			{"id": "track_guess_42", "label": "竞猜", "accent": Color("#c084fc"), "tooltip": "回到归属竞猜"},
			{"id": "track_open_orbital_finance_i", "label": "卡牌详情", "accent": Color("#f472b6"), "tooltip": "打开卡牌详情"},
		],
		"clues": [
			{"title": "已选牌轨证据链", "lines": ["牌槽证据｜#42｜竞拍1｜业主透镜｜归属待猜", "出牌条件｜轨迹墨水流动≥2", "目标线索｜区域：雾港", "出价记录｜锁定报价¥80", "余波线索｜金融｜T+12.0s｜GDP跳变", "私人推理｜尚未押注"], "accent": Color("#f472b6"), "tooltip": "已选牌轨", "line_limit": 6},
			{"title": "城市嫌疑", "lines": ["雾港｜优先88｜标P2/高｜GDP48｜仓储"], "accent": Color("#38bdf8"), "tooltip": "城市嫌疑"},
			{"title": "牌轨线索", "lines": ["业主透镜｜归属待猜｜需轨迹墨水"], "accent": Color("#f472b6"), "tooltip": "公开牌轨"},
			{"title": "怪兽资金", "lines": ["怪1受伤，疑似牵连仓储"], "accent": Color("#fb7185"), "tooltip": "怪兽资金"},
			{"title": "仓储/做空靶标", "lines": ["晶尘仓储绑定雾港"], "accent": Color("#fb923c"), "tooltip": "仓储风险"},
			{"title": "城市公开线索", "lines": ["雾港出现合约收入跳变"], "accent": Color("#4ade80"), "tooltip": "公开线索"},
			{"title": "下一步查证", "lines": ["先标高价值城市。"], "accent": Color("#a78bfa"), "tooltip": "下一步"},
		],
		"accent": Color("#c084fc"),
	})
	await process_frame
	_expect(String(board.name) == "IntelDossierBoardPanel", "IntelDossierBoard keeps the detective board root")
	_expect(board.find_child("IntelDossierBoardHeader", true, false) != null and board.find_child("IntelDossierBoardChip", true, false) != null, "IntelDossierBoard renders header chips")
	_expect(board.find_child("IntelDossierKpiGrid", true, false) != null and board.find_child("IntelDossierKpiCard", true, false) != null and board.find_child("IntelDossierKpiValue", true, false) != null, "IntelDossierBoard renders KPI cards")
	_expect(board.find_child("IntelDossierActionRow", true, false) != null, "IntelDossierBoard owns a focused anonymous-card action row")
	_expect(board.find_child("IntelDossierClueGrid", true, false) != null and board.find_child("IntelDossierClueCard", true, false) != null and board.find_child("IntelDossierClueLine", true, false) != null, "IntelDossierBoard renders clue cards")
	var board_text := _node_tree_text(board)
	_expect(board_text.contains("已选牌轨证据链") and board_text.contains("出价记录") and board_text.contains("余波线索") and board_text.contains("私人推理") and board_text.contains("回到牌轨") and board_text.contains("竞猜") and board_text.contains("卡牌详情"), "IntelDossierBoard can render a selected public-track evidence chain with bid, aftermath, private-note lines, and track/guess/detail paths")
	for label_text in ["回到牌轨", "竞猜", "卡牌详情"]:
		var action_button := _find_visible_button_containing(board, label_text)
		if action_button != null:
			action_button.emit_signal("pressed")
	await process_frame
	_expect(emitted_dossier_actions.has("track_return_42") and emitted_dossier_actions.has("track_guess_42") and emitted_dossier_actions.has("track_open_orbital_finance_i"), "IntelDossierBoard action buttons emit data-only public-track action ids")
	root.remove_child(board)
	board.queue_free()


func _check_standings_scoreboard_component() -> void:
	var packed := load("res://scenes/ui/StandingsScoreboard.tscn") as PackedScene
	_expect(packed != null, "StandingsScoreboard scene loads for standings checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_scoreboard"), "StandingsScoreboard owns scoreboard snapshot rendering")
	board.call("set_scoreboard", {
		"title": "局势记分板",
		"title_tooltip": "进行中只显示当前玩家可见资金；对手现金、手牌和真实资产仍靠推理。",
		"kpi_columns": 4,
		"seat_columns": 3,
		"chips": [
			{"text": "目标¥2200", "accent": Color("#fef3c7"), "tooltip": "终局目标"},
			{"text": "倒计时空闲", "accent": Color("#fb923c"), "tooltip": "终局沙漏"},
			{"text": "城市×700", "accent": Color("#4ade80"), "tooltip": "城市清算"},
			{"text": "对手隐私", "accent": Color("#94a3b8"), "tooltip": "隐藏资金和手牌"},
		],
		"kpis": [
			{"title": "我的终局距离", "value": "¥900/2200", "meta": "差¥1300｜现金¥620", "accent": Color("#38bdf8"), "tooltip": "当前玩家可见估值"},
			{"title": "城市现金流", "value": "2座", "meta": "GDP/min 180", "accent": Color("#4ade80"), "tooltip": "城市现金流"},
			{"title": "公开异动", "value": "5条", "meta": "牌轨/怪兽/天气", "accent": Color("#c084fc"), "tooltip": "公开线索"},
			{"title": "反超方向", "value": "压领先", "meta": "做空/断路/引怪兽", "accent": Color("#fb7185"), "tooltip": "反超方向"},
		],
		"seats": [
			{
				"name": "P1｜玩家1",
				"rank": "#1",
				"score": "¥900",
				"score_color": Color("#fef3c7"),
				"chips": [
					{"text": "现金¥620", "accent": Color("#fef3c7"), "tooltip": "现金"},
					{"text": "城2", "accent": Color("#bbf7d0"), "tooltip": "城市"},
					{"text": "GDP180", "accent": Color("#bfdbfe"), "tooltip": "GDP"},
				],
				"meta": "离目标¥1300",
				"accent": Color("#38bdf8"),
			},
			{
				"name": "P2｜对手",
				"rank": "#2",
				"score": "资金隐私",
				"score_color": Color("#94a3b8"),
				"chips": [
					{"text": "现金隐藏", "accent": Color("#94a3b8"), "tooltip": "隐藏"},
					{"text": "手牌隐藏", "accent": Color("#94a3b8"), "tooltip": "隐藏"},
					{"text": "资产靠推理", "accent": Color("#c4b5fd"), "tooltip": "推理"},
				],
				"meta": "看公开线索推测。",
				"accent": Color("#c084fc"),
			},
			{
				"name": "P3｜破产席",
				"rank": "#3",
				"score": "出局",
				"score_color": Color("#fb7185"),
				"eliminated": true,
				"chips": [
					{"name": "StandingsBankruptBadge", "text": "破产出局", "accent": Color("#fecdd3"), "tooltip": "公开破产"},
					{"text": "现金0", "accent": Color("#fef3c7"), "tooltip": "资金"},
				],
				"meta": "现金归零，提前退出本局。",
				"accent": Color("#64748b"),
			},
		],
		"hint": "读法：自己的牌看精确钱；对手牌看公开线索。",
		"accent": Color("#facc15"),
	})
	await process_frame
	_expect(String(board.name) == "StandingsScoreboardPanel", "StandingsScoreboard keeps the scoreboard panel root")
	_expect(board.find_child("StandingsScoreboardHeader", true, false) != null and board.find_child("StandingsScoreboardChip", true, false) != null, "StandingsScoreboard renders header chips")
	_expect(board.find_child("StandingsRaceKpiGrid", true, false) != null and board.find_child("StandingsRaceKpiCard", true, false) != null and board.find_child("StandingsRaceKpiValue", true, false) != null, "StandingsScoreboard renders race KPI cards")
	_expect(board.find_child("StandingsPlayerScoreGrid", true, false) != null and board.find_child("StandingsPlayerScoreCard", true, false) != null and board.find_child("StandingsBankruptBadge", true, false) != null, "StandingsScoreboard renders player score cards and bankruptcy badges")
	root.remove_child(board)
	board.queue_free()


func _check_final_settlement_board_component() -> void:
	var packed := load("res://scenes/ui/FinalSettlementBoard.tscn") as PackedScene
	_expect(packed != null, "FinalSettlementBoard scene loads for settlement checks")
	if packed == null:
		return
	var board := packed.instantiate() as Control
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_board"), "FinalSettlementBoard owns final settlement snapshot rendering")
	board.call("set_board", {
		"title": "终局速览｜赛后记分板",
		"kpi_columns": 4,
		"money_columns": 2,
		"rank_columns": 2,
		"action_columns": 3,
		"chips": [
			{"text": "胜者:玩家1", "accent": Color("#facc15"), "tooltip": "胜者"},
			{"text": "目标¥2200", "accent": Color("#fef3c7"), "tooltip": "目标"},
			{"text": "城值¥700", "accent": Color("#4ade80"), "tooltip": "城市清算"},
		],
		"kpis": [
			{"title": "胜者", "body": "玩家1｜结算资金¥3200", "meta": "游戏结束：测试", "accent": Color("#facc15")},
			{"title": "钱从哪里来", "body": "城收:玩家1 ¥900｜卡牌:玩家2 ¥400｜角色:玩家1 ¥120", "meta": "情报现金也进入排名。", "accent": Color("#4ade80")},
			{"title": "关键地图", "body": "雾港｜玩家1｜末期GDP¥120", "meta": "地图影响。", "accent": Color("#38bdf8")},
			{"title": "关键影响", "body": "匿名卡改变商路｜怪兽破坏港口", "meta": "公开事件。", "accent": Color("#c084fc")},
		],
		"money_sources": [
			{
				"title": "#1 玩家1｜¥3200",
				"start_line": "起手:基础¥500 + 角色+120 = ¥620",
				"settlement_line": "现金¥1800｜城值¥1400｜情报+0",
				"income_line": "城收¥900｜卡牌¥400｜角色¥120",
				"status_line": "支出¥300｜城2｜GDP/min 180｜在局",
				"accent": Color("#facc15"),
			},
		],
		"event_lines": [
			"关键卡牌：匿名合约改变雾港收入。",
			"地图结局：存活城市2座｜已毁区域1个｜怪兽在场1/2。",
		],
		"ranks": [
			{
				"title": "#1｜玩家1",
				"score": "¥3200",
				"stats": "现金¥1800｜城2｜GDP/min 180",
				"income": "城收¥900｜卡牌¥400｜情报+0",
				"identity": "真人/本地玩家",
				"accent": Color("#facc15"),
			},
			{
				"title": "#2｜玩家2",
				"score": "¥2100",
				"stats": "现金¥700｜城2｜GDP/min 110",
				"income": "城收¥500｜卡牌¥300｜情报-60",
				"identity": "电脑对手｜身份线索保密",
				"accent": Color("#c084fc"),
			},
		],
		"actions": [
			{"id": "standings", "title": "查看局势排名", "body": "逐席查看结算。", "accent": Color("#facc15")},
			{"id": "economy", "title": "打开经济总览", "body": "复查商品和GDP。", "accent": Color("#4ade80")},
			{"id": "new_run", "title": "开局准备", "body": "再开一桌。", "accent": Color("#67e8f9")},
		],
		"accent": Color("#facc15"),
	})
	await process_frame
	_expect(String(board.name) == "FinalSettlementBoardPanel", "FinalSettlementBoard keeps the final settlement panel root")
	_expect(board.find_child("FinalSettlementHeader", true, false) != null and board.find_child("FinalSettlementHeaderChip", true, false) != null, "FinalSettlementBoard renders header chips")
	_expect(board.find_child("FinalSettlementKpiGrid", true, false) != null and board.find_child("FinalSettlementKpiCard", true, false) != null, "FinalSettlementBoard renders KPI cards")
	_expect(board.find_child("FinalSettlementMoneySourcePanel", true, false) != null and board.find_child("FinalSettlementMoneySourceCard", true, false) != null and board.find_child("FinalSettlementStartingCashLine", true, false) != null, "FinalSettlementBoard renders money-source cards with starting cash lines")
	_expect(board.find_child("FinalSettlementEventPanel", true, false) != null and board.find_child("FinalSettlementEventLine", true, false) != null, "FinalSettlementBoard renders public event lines")
	_expect(board.find_child("FinalSettlementRankTrack", true, false) != null and board.find_child("FinalSettlementRankCard", true, false) != null, "FinalSettlementBoard renders ranking cards")
	_expect(board.find_child("FinalSettlementAfterActionGrid", true, false) != null and board.find_child("FinalSettlementAfterActionButton", true, false) != null, "FinalSettlementBoard renders after-action buttons")
	root.remove_child(board)
	board.queue_free()


func _check_code_layer_contracts() -> void:
	var forbidden_viewmodel_tokens := [
		"Button.new(",
		"Label.new(",
		"PanelContainer.new(",
		"Control.new(",
		"CanvasLayer",
		"Node2D",
		"Sprite2D",
		"add_child(",
		"queue_free(",
		"get_tree(",
		"Callable(",
		"pressed.connect",
	]
	for script_path in VIEWMODEL_SCRIPT_PATHS:
		var source := FileAccess.get_file_as_string(script_path)
		_expect(source != "", "%s readable for ViewModel layer contract" % script_path)
		for token in forbidden_viewmodel_tokens:
			_expect(not source.contains(token), "%s ViewModel layer does not create UI nodes or bind UI signals (%s)" % [script_path, token])

	var forbidden_ui_tokens := [
		"players",
		"districts",
		"auto_monsters",
		"military_units",
		"game_over",
		"_city_build_error_for",
		"_can_buy_card_from_district",
		"_use_skill",
		"_build_city",
		"_summon",
		"_apply_",
		"res://scenes/main.tscn",
	]
	for script_path in SPLIT_UI_SCRIPT_PATHS:
		var source := FileAccess.get_file_as_string(script_path)
		_expect(source != "", "%s readable for UI renderer layer contract" % script_path)
		for token in forbidden_ui_tokens:
			_expect(not source.contains(token), "%s UI scene renderer consumes snapshots/signals instead of domain state or rule functions (%s)" % [script_path, token])


func _check_hand_rack_v3_interaction_contract() -> void:
	var packed := load("res://scenes/ui/HandRack.tscn") as PackedScene
	_expect(packed != null, "HandRack scene loads for commercial cardfeel v3")
	if packed == null:
		return
	var hand := packed.instantiate() as Control
	hand.size = Vector2(1000, 250)
	root.add_child(hand)
	var selected_events: Array[String] = []
	var unselected_events: Array[String] = []
	var drag_releases: Array[String] = []
	if hand.has_signal("card_selected"):
		hand.connect("card_selected", func(card_data: Dictionary) -> void:
			selected_events.append(str(card_data.get("id", "")))
		)
	if hand.has_signal("card_unselected"):
		hand.connect("card_unselected", func(card_data: Dictionary) -> void:
			unselected_events.append(str(card_data.get("id", "")))
		)
	if hand.has_signal("card_drag_released"):
		hand.connect("card_drag_released", func(card_data: Dictionary, _screen_position: Vector2) -> void:
			drag_releases.append(str(card_data.get("id", "")))
		)
	hand.call("set_cards", [
		{"id": "feel_v3_a", "name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "短效果。", "actions": [{"id": "play_0", "label": "出牌"}]},
		{"id": "feel_v3_b", "name": "雾港合约", "cost": "3", "type": "合约", "rank": "II", "effect": "短效果。", "actions": [{"id": "play_1", "label": "出牌"}]},
		{"id": "feel_v3_c", "name": "冷却卡", "cost": "1", "type": "互动", "rank": "I", "effect": "短效果。", "drop_enabled": false, "actionable": false, "play_state": "冷却", "block_reason": "冷却中", "actions": [{"id": "play_2", "label": "出牌", "disabled": true}]},
	])
	await process_frame
	_expect(hand.has_signal("card_unselected"), "HandRack exposes card_unselected for stable selected-card focus")
	_expect(hand.get_child_count() == 3, "HandRack v3 renders three CardFace children")
	var first := hand.get_child(0) as Control
	var second := hand.get_child(1) as Control
	var disabled := hand.get_child(2) as Control
	_single_click_card_control(first)
	await process_frame
	_expect(selected_events.has("feel_v3_a"), "single-clicking a HandRack card emits card_selected")
	var selected_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var selected_snapshot: Array = selected_snapshot_variant if selected_snapshot_variant is Array else []
	_expect(selected_snapshot.size() == 3, "HandRack v3 snapshot exposes every rendered card")
	if selected_snapshot.size() < 3:
		root.remove_child(hand)
		hand.queue_free()
		return
	_expect(bool((selected_snapshot[0] as Dictionary).get("selected", false)) and not bool((selected_snapshot[0] as Dictionary).get("hovered", false)), "selected card remains a stable focus separate from hover")
	var selected_entry: Dictionary = selected_snapshot[0] as Dictionary
	var disabled_entry: Dictionary = selected_snapshot[2] as Dictionary
	_expect(selected_entry.has("target_position") and selected_entry.has("target_rotation") and selected_entry.has("target_scale") and selected_entry.has("visible_ratio") and selected_entry.has("overflow_hidden"), "HandRack v3 snapshot includes target motion and overflow visibility fields")
	_expect(str(disabled_entry.get("drag_state", "")) == "disabled", "disabled hand cards advertise disabled drag_state before dragging")
	hand.call("set_hovered_card", second)
	await process_frame
	var hover_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var hover_snapshot: Array = hover_snapshot_variant if hover_snapshot_variant is Array else []
	_expect(bool((hover_snapshot[0] as Dictionary).get("selected", false)) and bool((hover_snapshot[1] as Dictionary).get("hovered", false)), "hovering another card does not clear the selected card")
	hand.call("set_hovered_card", null)
	await process_frame
	var post_hover_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var post_hover_snapshot: Array = post_hover_snapshot_variant if post_hover_snapshot_variant is Array else []
	_expect(bool((post_hover_snapshot[0] as Dictionary).get("selected", false)) and not bool((post_hover_snapshot[1] as Dictionary).get("hovered", false)), "leaving hover returns to the stable selected card")
	hand.call("set_dragged_card", disabled, false)
	await process_frame
	var invalid_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var invalid_snapshot: Array = invalid_snapshot_variant if invalid_snapshot_variant is Array else []
	var invalid_entry: Dictionary = invalid_snapshot[2] as Dictionary
	_expect(bool(invalid_entry.get("dragging", false)) and bool(invalid_entry.get("drop_invalid", false)) and str(invalid_entry.get("drag_state", "")) == "invalid_drop" and int(invalid_entry.get("z_index", 0)) >= 1100, "invalid drop is a distinct dragging state with top z-index")
	hand.call("clear_dragged_card")
	await process_frame
	var return_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var return_snapshot: Array = return_snapshot_variant if return_snapshot_variant is Array else []
	_expect(not bool((return_snapshot[2] as Dictionary).get("dragging", false)) and str((return_snapshot[2] as Dictionary).get("drag_state", "")) == "returning" and bool((return_snapshot[0] as Dictionary).get("selected", false)), "clearing invalid drag returns the card while preserving selected focus")
	_drag_card_control_to_screen(disabled, hand.get_global_rect().get_center() + Vector2(120, -80))
	await process_frame
	_expect(drag_releases.has("feel_v3_c"), "drag release from HandRack only emits card_drag_released data")
	var background_click := InputEventMouseButton.new()
	background_click.button_index = MOUSE_BUTTON_LEFT
	background_click.pressed = true
	hand.call("_gui_input", background_click)
	await process_frame
	_expect(unselected_events.has("feel_v3_a"), "clicking the empty HandRack background clears the selected card")
	root.remove_child(hand)
	hand.queue_free()


func _check_card_face_presentation_specs() -> void:
	var packed := load("res://scenes/ui/CardFace.tscn") as PackedScene
	_expect(packed != null, "CardFace scene loads for presentation specs")
	if packed == null:
		return
	var mini := packed.instantiate() as Control
	root.add_child(mini)
	mini.size = Vector2(96, 128)
	mini.call("set_card_data", {
		"id": "mini_spec",
		"name": "超长轨道融资测试卡",
		"cost": "2",
		"type": "经济",
		"rank": "I",
		"effect": "这是一段很长的规则说明，MiniCard 不应该把它完整塞进底部手牌。",
		"presentation": "mini_hand",
	})
	await process_frame
	var mini_effect := mini.find_child("EffectLabel", true, false) as Label
	var keyword_rail := mini.find_child("KeywordChipRail", true, false)
	var art_view := mini.find_child("ArtView", true, false)
	_expect(str(mini.get_meta("card_presentation_spec", "")) == "MiniCard" and mini_effect != null and mini_effect.max_lines_visible <= 3 and mini_effect.autowrap_mode != TextServer.AUTOWRAP_OFF and mini_effect.text.length() < 56 and keyword_rail != null and keyword_rail.get_child_count() >= 2 and art_view != null and bool(art_view.get_meta("card_face_visual_anchor", false)), "MiniCard presentation keeps a visual art anchor, 2-3 line scan effect, and keyword chips instead of long rules")
	root.remove_child(mini)
	mini.queue_free()

	var inspector := packed.instantiate() as Control
	root.add_child(inspector)
	inspector.size = Vector2(240, 320)
	inspector.call("set_card_data", {
		"id": "inspector_spec",
		"name": "轨道融资",
		"cost": "2",
		"type": "经济",
		"rank": "II",
		"target": "己方城市",
		"requirement": "选区有城市",
		"effect": "现金流上升并留下公开线索。",
		"disabled_reason": "当前未选城市",
		"presentation": "inspector_full",
		"actions": [{"id": "play_0", "label": "出牌", "disabled": false}],
	})
	await process_frame
	var inspector_effect := inspector.find_child("EffectLabel", true, false) as Label
	var inspector_text := inspector_effect.text if inspector_effect != null else ""
	_expect(str(inspector.get_meta("card_presentation_spec", "")) == "inspector_full" and inspector_text.contains("目标｜己方城市") and inspector_text.contains("条件｜选区有城市") and inspector_text.contains("主动作｜出牌") and inspector_text.contains("暂不可用｜当前未选城市"), "inspector_full presentation carries target, requirement, full effect, action, and disabled reason")
	inspector.call("set_interaction_state", {"selected": true, "hovered": false, "dragging": false, "drop_valid": true, "drop_invalid": false})
	_expect(str(inspector.get_meta("card_visual_state", "")) == "selected", "CardFace exposes selected visual state metadata")
	root.remove_child(inspector)
	inspector.queue_free()


func _check_empty_player_board_affordance() -> void:
	var packed := load("res://scenes/ui/PlayerBoard.tscn") as PackedScene
	_expect(packed != null, "PlayerBoard scene loads for empty-hand affordance")
	if packed == null:
		return
	var board := packed.instantiate()
	root.add_child(board)
	await process_frame
	_expect(board.has_method("set_player_state"), "PlayerBoard accepts player-state snapshots")
	board.call("set_player_state", {"title": "玩家板｜空手牌", "hand_cards": []})
	await process_frame
	var hand_rack := board.find_child("HandRack", true, false)
	_expect(hand_rack != null, "PlayerBoard keeps a HandRack node for empty hands")
	_expect(hand_rack != null and hand_rack.get_child_count() == 1 and hand_rack.get_child(0) is Label, "PlayerBoard renders an empty-hand affordance instead of collapsing the rack")
	_expect(hand_rack != null and _node_tree_text(hand_rack).contains("暂无手牌") and _node_tree_text(hand_rack).contains("区域牌架"), "empty HandRack copy points the player to supply instead of sounding like debug text")
	board.call("set_player_state", {"title": "玩家板｜手牌", "hand_cards": [{"id": "stable_card_0", "name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "现金流上升。"}]})
	await process_frame
	var first_card_id := -1
	if hand_rack != null and hand_rack.get_child_count() > 0:
		first_card_id = hand_rack.get_child(0).get_instance_id()
	board.call("set_player_state", {"title": "玩家板｜手牌", "hand_cards": [{"id": "stable_card_0", "name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "现金流说明更新。"}]})
	await process_frame
	var stable_card: Control = null
	if hand_rack != null and hand_rack.get_child_count() > 0:
		stable_card = hand_rack.get_child(0) as Control
	var stable_card_data: Dictionary = stable_card.call("get_card_data") if stable_card != null and stable_card.has_method("get_card_data") else {}
	_expect(stable_card != null and stable_card.get_instance_id() == first_card_id, "PlayerBoard keeps same-id hand card nodes across card-detail snapshot updates")
	_expect(stable_card_data.get("effect", "") == "现金流说明更新。", "PlayerBoard still updates card-face data when reusing the same hand card node")
	_expect(stable_card != null and stable_card.name.begins_with("MiniHandCardFace"), "PlayerBoard names reused hand cards as MiniCard faces")
	_expect(stable_card_data.get("presentation") == "mini_hand" and stable_card_data.get("detail_policy") == "right_inspector", "PlayerBoard direct hand-card input still renders as MiniCard and sends full detail to RightInspector")
	var double_click_actions: Array[String] = []
	if board.has_signal("action_requested"):
		board.connect("action_requested", func(action_id: String) -> void:
			double_click_actions.append(action_id)
		)
	board.call("set_player_state", {
		"title": "玩家板｜手牌",
		"hand_cards": [{
			"id": "stable_card_0",
			"name": "轨道融资",
			"cost": "2",
			"type": "经济",
			"rank": "I",
			"effect": "现金流说明更新。",
			"actions": [{"id": "play_0", "label": "出牌", "disabled": false}],
		}],
	})
	await process_frame
	if hand_rack != null and hand_rack.get_child_count() > 0:
		stable_card = hand_rack.get_child(0) as Control
	if stable_card != null:
		_double_click_card_control(stable_card)
		await process_frame
	_expect(double_click_actions.has("play_0"), "PlayerBoard double-clicks an enabled hand card into its snapshot play action")
	root.remove_child(board)
	board.queue_free()


func _check_main_player_panel_refresh_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var player_board_source := FileAccess.get_file_as_string("res://scripts/ui/player_board.gd")
	var hand_rack_source := FileAccess.get_file_as_string("res://scripts/ui/hand_rack.gd")
	_expect(main_source.contains("var player_panel_signature"), "main UI tracks a player panel structure signature")
	_expect(main_source.contains("func _uses_split_runtime_table") and main_source.contains("func _refresh_split_compatibility_player_panel") and main_source.contains("if _uses_split_runtime_table():") and main_source.contains("_refresh_split_compatibility_player_panel()") and main_source.contains("_refresh_player_panel(false)"), "default split runtime uses a narrow decision compatibility host while legacy fallback can still refresh the full PlayerBoard")
	_expect(main_source.contains("func _player_panel_structure_signature"), "main UI can decide when PlayerBoard structure changed")
	_expect(main_source.contains("func _refresh_player_panel_live_values"), "main UI updates live resource values without destroy/recreate")
	_expect(main_source.contains("func _activate_runtime_quick_action") and main_source.contains("\"build\", \"rack\", \"buy\", \"play\"") and main_source.contains("_runtime_quick_action_entry(player_index, action_id)"), "main runtime routes split ActionDock quick actions back into the existing controller")
	_expect(main_source.contains("_build_city_in_selected_district()") and main_source.contains("_open_district_supply_from_map(selected_district)") and main_source.contains("_first_actionable_hand_slot(player_index)") and main_source.contains("_use_skill(slot_index)"), "main runtime quick actions drive build, rack/buy, and play through existing gameplay entry points")
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(game_screen_source.contains("func _unhandled_key_input") and game_screen_source.contains("_quick_action_index_for_key") and game_screen_source.contains("_quick_action_id_at") and game_screen_source.contains("_should_ignore_quick_action_hotkey"), "split GameScreen maps 1-4 keyboard shortcuts onto the current data-backed quick actions without reading gameplay rules")
	_expect(main_source.contains("_on_runtime_game_screen_card_drop_requested") and main_source.contains("_runtime_drop_position_targets_map(screen_position)") and main_source.contains("get_district_at_control_position"), "main runtime maps split hand-card drops onto MapView districts before using existing play-card controller flow")
	_expect(player_board_source.contains("hand_rack.call(\"set_cards\", cards)") and not player_board_source.contains("hand_rack.remove_child"), "split PlayerBoard delegates hand rendering to HandRack instead of clearing card nodes")
	_expect(player_board_source.contains("func _first_enabled_card_action_id") and player_board_source.contains("card_double_selected") and player_board_source.contains("action_requested.emit(action_id)"), "split PlayerBoard turns a double-clicked enabled hand card into its snapshot action instead of reading gameplay rules")
	_expect(hand_rack_source.contains("func set_cards") and hand_rack_source.contains("_card_identity_key") and hand_rack_source.contains("_sync_card_nodes"), "split HandRack performs same-id card-node synchronization for live snapshot rendering")
	_expect(hand_rack_source.contains("signal card_unselected") and hand_rack_source.contains("_selected_identity") and hand_rack_source.contains("_select_card_node") and hand_rack_source.contains("_unselect_current_card"), "split HandRack owns stable selected-card focus without relying on hover")
	_expect(hand_rack_source.contains("signal card_drag_released") and hand_rack_source.contains("_event_screen_position") and hand_rack_source.contains("card_drag_released.emit") and hand_rack_source.contains("_card_drag_drop_valid") and not hand_rack_source.contains("_use_skill"), "split HandRack reports card drag release coordinates and invalid-drop state without reading gameplay rules")


func _check_hand_layout_counts() -> void:
	var card_scene := load("res://scenes/CardUI.tscn")
	var hand_script := load("res://scripts/HandLayout.gd")
	_expect(card_scene != null, "CardUI scene loads for hand layout")
	_expect(hand_script != null, "HandLayout script loads for direct layout checks")
	if card_scene == null or hand_script == null:
		return
	for count in [0, 1, 5, 10, 15]:
		var hand := hand_script.new() as Control
		hand.size = Vector2(1000, 250)
		root.add_child(hand)
		for i in range(count):
			var card := card_scene.instantiate() as Control
			hand.add_child(card)
		hand.relayout()
		await process_frame
		_expect(hand.get_child_count() == count, "HandLayout keeps %d cards" % count)
		for child in hand.get_children():
			if child is Control:
				var card := child as Control
				_expect(card.position.x >= -1.0, "hand card stays within left bound for %d cards" % count)
				_expect(card.position.x + card.size.x <= hand.size.x + 1.0, "hand card stays within right bound for %d cards" % count)
		var snapshot_variant: Variant = hand.call("get_card_target_snapshot") if hand.has_method("get_card_target_snapshot") else []
		var snapshot: Array = snapshot_variant if snapshot_variant is Array else []
		if count == 1 and snapshot.size() == 1:
			var single_card := hand.get_child(0) as Control
			var single_position := _snapshot_position(snapshot[0])
			var expected_single_x := (hand.size.x - single_card.size.x) * 0.5
			_expect(_snapshot_profile(snapshot[0]) == "single_focus" and absf(_snapshot_rotation(snapshot[0])) <= deg_to_rad(0.1) and absf(single_position.x - expected_single_x) <= 1.5, "HandLayout centers a single card without fan rotation")
		if count == 5 and snapshot.size() >= 5:
			var five_card := hand.get_child(0) as Control
			var five_gap := _snapshot_gap_x(snapshot, 0, 1)
			_expect(_snapshot_profile(snapshot[2]) == "comfortable" and five_gap >= five_card.size.x * 0.68 and five_gap <= five_card.size.x * 0.80, "HandLayout uses a comfortable CardHouse-style spread for five cards")
			_expect(absf(_snapshot_rotation(snapshot[0])) > deg_to_rad(4.0) and absf(_snapshot_rotation(snapshot[4])) > deg_to_rad(4.0), "HandLayout gives a visible commercial-card fan to a normal hand")
		if count == 10 and snapshot.size() >= 10:
			var ten_card := hand.get_child(0) as Control
			var ten_gap := _snapshot_gap_x(snapshot, 0, 1)
			_expect(_snapshot_profile(snapshot[5]) == "compressed" and ten_gap <= ten_card.size.x * 0.60, "HandLayout compresses a ten-card hand instead of turning it into a button list")
			_expect(absf(_snapshot_rotation(snapshot[0])) >= deg_to_rad(8.0) and absf(_snapshot_rotation(snapshot[9])) >= deg_to_rad(8.0), "HandLayout strengthens the fan when the rack is crowded")
		if count == 15 and snapshot.size() >= 15:
			var fifteen_card := hand.get_child(0) as Control
			var fifteen_gap := _snapshot_gap_x(snapshot, 0, 1)
			_expect(_snapshot_profile(snapshot[7]) == "pressure" and fifteen_gap <= fifteen_card.size.x * 0.42, "HandLayout enters a pressure profile for very full hands")
			_expect(_snapshot_drop_zone(snapshot[7]).size.y >= 28.0, "HandLayout exposes a bottom drop-preview zone for UI-only drag feedback")
		if count == 5:
			await _check_hand_layout_motion_targets(hand)
		root.remove_child(hand)
		hand.queue_free()


func _check_hand_layout_motion_targets(hand: Control) -> void:
	_expect(hand.has_method("get_card_target_snapshot"), "HandLayout exposes motion target snapshots for hover QA")
	if not hand.has_method("get_card_target_snapshot") or not hand.has_method("set_hovered_card"):
		return
	var before_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var before_snapshot: Array = before_snapshot_variant if before_snapshot_variant is Array else []
	if before_snapshot.size() < 5 or hand.get_child_count() < 5:
		_expect(false, "HandLayout motion target test has five card entries")
		return
	var left_before := _snapshot_position(before_snapshot[1])
	var hovered_before := _snapshot_position(before_snapshot[2])
	var right_before := _snapshot_position(before_snapshot[3])
	var hovered_card := hand.get_child(2) as Control
	hand.call("set_hovered_card", hovered_card)
	await process_frame
	var after_snapshot_variant: Variant = hand.call("get_card_target_snapshot")
	var after_snapshot: Array = after_snapshot_variant if after_snapshot_variant is Array else []
	if after_snapshot.size() < 5:
		_expect(false, "HandLayout hover motion target snapshot remains complete")
		return
	var hovered_entry := _snapshot_entry(after_snapshot[2])
	var left_after := _snapshot_position(after_snapshot[1])
	var hovered_after := _snapshot_position(after_snapshot[2])
	var right_after := _snapshot_position(after_snapshot[3])
	var hovered_scale := _snapshot_scale(after_snapshot[2])
	var hovered_z := int(hovered_entry.get("z_index", 0))
	_expect(bool(hovered_entry.get("hovered", false)) and hovered_scale.x > 1.0 and hovered_z >= 1000, "HandLayout hover target scales and raises the focused card")
	_expect(hovered_after.y <= hovered_before.y - 34.0 and str(hovered_entry.get("profile", "")) == "comfortable", "HandLayout hover target lifts the focused card out of the rack while preserving the layout profile")
	_expect(left_after.x < left_before.x and right_after.x > right_before.x, "HandLayout hover target pushes neighbor cards aside")
	_expect(hovered_card != null and hovered_card.scale.x > 1.0, "HandLayout seeker begins moving hovered card within one frame")


func _snapshot_entry(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _snapshot_position(value: Variant) -> Vector2:
	var entry := _snapshot_entry(value)
	var position_variant: Variant = entry.get("position", Vector2.ZERO)
	return position_variant if position_variant is Vector2 else Vector2.ZERO


func _snapshot_scale(value: Variant) -> Vector2:
	var entry := _snapshot_entry(value)
	var scale_variant: Variant = entry.get("scale", Vector2.ONE)
	return scale_variant if scale_variant is Vector2 else Vector2.ONE


func _snapshot_rotation(value: Variant) -> float:
	var entry := _snapshot_entry(value)
	return float(entry.get("rotation", 0.0))


func _snapshot_profile(value: Variant) -> String:
	var entry := _snapshot_entry(value)
	return str(entry.get("profile", ""))


func _snapshot_drop_zone(value: Variant) -> Rect2:
	var entry := _snapshot_entry(value)
	var zone_variant: Variant = entry.get("drop_zone", Rect2())
	return zone_variant if zone_variant is Rect2 else Rect2()


func _snapshot_gap_x(snapshot: Array, left_index: int, right_index: int) -> float:
	if snapshot.size() <= maxi(left_index, right_index):
		return 0.0
	return _snapshot_position(snapshot[right_index]).x - _snapshot_position(snapshot[left_index]).x


func _has_forbidden_2d_ui(node: Node) -> bool:
	if node is Node2D or node is Sprite2D:
		return true
	for child in node.get_children():
		if _has_forbidden_2d_ui(child):
			return true
	return false


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_node_tree_text(child))
	return " ".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		push_error(message)
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Layout scene smoke test passed.")
		quit(0)
	else:
		printerr("Layout scene smoke test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
