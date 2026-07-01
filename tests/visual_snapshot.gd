extends SceneTree

const MAIN_SOURCE_PATH := "res://scripts/main.gd"
const MAP_SOURCE_PATH := "res://scripts/map_view.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var map_source := FileAccess.get_file_as_string(MAP_SOURCE_PATH)
	_expect(main_source != "", "main.gd can be read for visual layout contract checks")
	_expect(map_source != "", "map_view.gd can be read for planet projection contract checks")
	_expect(main_source.contains("太空辛迪加｜星球赌桌") and main_source.contains("星球赌桌｜中央星球"), "main table keeps the gambling-table planet theme")
	_expect(main_source.contains("MainMenuPlanetLobbyPanel") and main_source.contains("MainMenuPlanetLobbyBody") and main_source.contains("MainMenuPlanetMedallion") and main_source.contains("MainMenuLobbyKpiGrid") and main_source.contains("MainMenuLobbyActionGrid"), "main menu uses a board-game planet lobby before branch lists")
	_expect(main_source.contains("HeaderStatusChipRail") and main_source.contains("HeaderStatusChip") and main_source.contains("◆ 空闲") and main_source.contains("◷ 00:00") and main_source.contains("♛ 目标") and main_source.contains("_set_header_status_chip(\"tempo\""), "top table status uses compact board-game chips instead of one long debug line")
	_expect(main_source.contains("MapControlBar") and main_source.contains("MapControlChipRail") and main_source.contains("MapControlChip") and main_source.contains("◎ 赌桌中央") and main_source.contains("双击看牌"), "map toolbar uses compact board-game control chips while keeping the planet central")
	_expect(main_source.contains("map_view.custom_minimum_size = Vector2(560, 430)"), "main map keeps a large central minimum footprint")
	_expect(main_source.contains("WeatherForecastBar") and main_source.contains("WeatherForecastChipRail") and main_source.contains("☄ 天气预报"), "weather forecast uses a compact board-game chip rail on the main table")
	_expect(main_source.contains("CardResolutionTableBanner") and main_source.contains("dock.anchor_left = 0.27") and main_source.contains("dock.anchor_right = 0.66"), "card resolution reveal uses a top-center table banner instead of fighting the right-side card drawer")
	_expect(main_source.contains("全桌结算横幅") and main_source.contains("不遮住右侧牌架或底部手牌") and main_source.contains("BottomCountdownOverlay") and main_source.contains("BottomCountdownPanel") and main_source.contains("CardResolutionRevealTimerBar") and main_source.contains("_refresh_bottom_countdown_bar"), "card resolution banner stays compact while the bottom table sandglass owns countdown timing")
	_expect(main_source.contains("匿名牌轨") and main_source.contains("CardResolutionTtaMarketPanel") and main_source.contains("CardResolutionTtaOfferRailFrame") and main_source.contains("CardResolutionTtaMarketHeader") and main_source.contains("panel.custom_minimum_size = Vector2(0, 48)") and main_source.contains("公共牌槽") and main_source.contains("CardResolutionTtaSlotMarketMat") and main_source.contains("CardResolutionTtaAgeMarketRuler") and main_source.contains("CardResolutionTtaCostBandRail") and main_source.contains("CardResolutionTtaCostCell") and main_source.contains("CardResolutionTtaSlotGrooveRail") and main_source.contains("CardResolutionTtaScrollShell") and main_source.contains("CardResolutionTtaScrollCue") and main_source.contains("CARD_TRACK_VISIBLE_SLOT_COUNT := 12") and main_source.contains("CARD_TRACK_SLOT_HEIGHT := 30") and main_source.contains("CARD_TRACK_MANUAL_SCROLL_HOLD_MSEC") and main_source.contains("CardResolutionTtaGhostSlot") and main_source.contains("CardResolutionTtaMiniCard") and main_source.contains("CardResolutionTtaSlotIndex") and main_source.contains("CardResolutionCostPipRail") and main_source.contains("_set_card_resolution_track_slot_hover") and main_source.contains("_maybe_follow_card_resolution_track"), "anonymous card track uses a compact Through-the-Ages-like public card-slot rail")
	_expect(main_source.contains("player_box = _add_panel(player_panel_scroll, \"桌边牌架\")"), "player hand area is framed as a scroll-safe table-edge rack")
	_expect(main_source.contains("TerraformingMarsLikeResourceBoard") and main_source.contains("PlayerResourceCubeRail") and main_source.contains("PlayerResourceCube"), "bottom player area includes a Terraforming-Mars-like resource cube board")
	_expect(main_source.contains("table_rail.name = \"PlayerTableRail\"") and main_source.contains("hand_column.name = \"PlayerHandColumn\"") and main_source.contains("tray_column.name = \"PlayerActionColumn\""), "bottom player rail keeps hand cards and action tray side-by-side")
	_expect(main_source.contains("PlayerTableauBoard") and main_source.contains("PlayerIdentityMiniCard") and main_source.contains("PlayerTableauGoalMeter") and main_source.contains("PlayerTableauGoalProgressBar") and main_source.contains("PlayerTableauChipGrid") and main_source.contains("PlayerSeatSelectorRail"), "bottom player area uses a board-game player tableau with public identity, goal meter, and resource chips")
	_expect(main_source.contains("TableGoalPrompt") and main_source.contains("TableGoalPrimaryActionRail") and main_source.contains("TableGoalPrimaryActionButton") and main_source.contains("TableGoalPromptChipRail") and main_source.contains("目标提示｜下一步"), "bottom rail keeps next-action guidance as a compact table-goal card with one primary CTA")
	_expect(main_source.contains("SelectedDistrictBoard") and main_source.contains("SelectedDistrictTilePlate") and main_source.contains("SelectedDistrictChipRail") and main_source.contains("SelectedDistrictActionLampRail") and main_source.contains("SelectedDistrictActionLampLabel") and main_source.contains("SelectedDistrictActionGrid") and main_source.contains("地块板｜选区行动") and main_source.contains("OpeningGuideTimeline") and main_source.contains("OpeningGuideStepToken") and main_source.contains("OpeningGuidePrimaryActionButton"), "selected district and opening guide use compact board-game tile/timeline components")
	_expect(main_source.contains("FirstSummonCard") and main_source.contains("FirstSummonChipRail") and main_source.contains("FirstSummonCardArt") and main_source.contains("FirstSummonDeployButton"), "first summon prompt is a table-side starter monster card instead of a prose row")
	_expect(main_source.contains("RoleCodexIdentityBoardPanel") and main_source.contains("RoleCodexIdentityHeader") and main_source.contains("RoleCodexIdentityChipRail") and main_source.contains("RoleCodexAbilityKpiGrid") and main_source.contains("RoleCodexRouteCard"), "role codex detail opens with a public identity board and route cards")
	_expect(main_source.contains("TutorialQuickStartPanel") and main_source.contains("TutorialQuickStartStepGrid") and main_source.contains("TutorialQuickStartTrapGrid") and main_source.contains("试玩速成板"), "tutorial menu uses a quick-start board with step and trap cards")
	_expect(main_source.contains("ActionTrayModuleChipRail") and main_source.contains("ActionTrayModuleChip") and main_source.contains("⌖选区") and main_source.contains("⇄合约"), "action tray exposes module chips before detailed controls")
	_expect(main_source.contains("TemporaryDecisionCard") and main_source.contains("TemporaryDecisionChipRail") and main_source.contains("桌边决策｜") and main_source.contains("ContractOfferTermsBoard") and main_source.contains("ContractOfferTermsHeader") and main_source.contains("ContractOfferDecisionTimerBar") and main_source.contains("ContractOfferTermRail") and main_source.contains("ContractOfferTermLamp") and main_source.contains("ContractOfferTermSignal") and main_source.contains("ContractOfferTermLabel"), "temporary decisions use a unified table-edge decision card with status chips and contract terms")
	_expect(main_source.contains("MonsterWagerChipRail") and main_source.contains("MonsterWagerSideChipRail") and main_source.contains("MonsterWagerPublicBetBoard") and main_source.contains("MonsterWagerPublicBetGrid") and main_source.contains("MonsterWagerPlayerToken") and main_source.contains("MonsterWagerBetLine") and main_source.contains("奖池¥"), "monster wagers expose pot, ante, timer, side chips, and public player bet slots")
	_expect(main_source.contains("panel.custom_minimum_size = Vector2(170, 198) if compact else Vector2(218, 268)"), "compact hand cards stay small enough for a bottom rack")
	_expect(main_source.contains("CardFaceChipRail") and main_source.contains("card_face_chip_rail") and main_source.contains("_add_card_face_chip_rail") and main_source.contains("HandCardPlayLamp") and main_source.contains("HandCardPlayLampStatus") and main_source.contains("HandCardPlayStateRail") and main_source.contains("HandCardPlayReason") and main_source.contains("var art_height := 50 if compact and is_hand_card else") and main_source.contains("action_button.custom_minimum_size = Vector2(0, 24)"), "card faces use compact chip rails and a status lamp for costs and hand-play status")
	_expect(main_source.contains("CardCodexTcgDetailLayout") and main_source.contains("CardCodexTcgSummaryPanel") and main_source.contains("扫牌顺序") and main_source.contains("CardCodexUpgradeLadder") and main_source.contains("CardCodexUpgradeStepCard"), "card codex detail uses a TCG-style quick-read panel and upgrade ladder")
	_expect(main_source.contains("ProductCodexMarketBoardPanel") and main_source.contains("ProductCodexMarketHeader") and main_source.contains("ProductCodexMarketChipRail") and main_source.contains("ProductCodexMarketKpiGrid") and main_source.contains("ProductCodexStrategyCard"), "product codex detail opens with a board-game commodity market board")
	_expect(main_source.contains("RegionCodexTileBoardPanel") and main_source.contains("RegionCodexTileHeader") and main_source.contains("RegionCodexTileChipRail") and main_source.contains("RegionCodexTileKpiGrid") and main_source.contains("RegionCodexClueCard"), "region codex detail opens with a board-game tile board and clue cards")
	_expect(main_source.contains("BestiaryMonsterBoardPanel") and main_source.contains("BestiaryMonsterHeader") and main_source.contains("BestiaryMonsterChipRail") and main_source.contains("BestiaryMonsterKpiGrid") and main_source.contains("BestiaryMonsterActionGrid") and main_source.contains("BestiaryMonsterActionCard"), "monster bestiary detail opens with a board-game monster unit board and action cards")
	_expect(main_source.contains("hand_scroll.custom_minimum_size = Vector2(0, 198)") and main_source.contains("PlayerHandRackPanel") and main_source.contains("PlayerHandRackChipRail") and main_source.contains("PlayerHandEmptySlot"), "hand rack reserves enough height and reads as a board-game card rack")
	_expect(main_source.contains("DistrictSupplyShelfBoard") and main_source.contains("DistrictSupplyShelfChipRail") and main_source.contains("牌架 %d") and main_source.contains("价格已锁") and main_source.contains("手牌 %d/%d"), "district card rack exposes a shelf board with compact market status and hand-pressure chips")
	_expect(main_source.contains("DistrictSupplySideDrawer") and main_source.contains("margin.anchor_left = 0.60") and main_source.contains("DistrictSupplyDrawerStack") and main_source.contains("DistrictSupplyMarketGrid") and main_source.contains("DistrictSupplyPreviewPanel"), "district card rack opens as a right-side market drawer instead of a central modal")
	_expect(main_source.contains("侧边牌架｜市场格｜悬停预览｜双击购买") and main_source.contains("DistrictSupplyRuleStrip") and main_source.contains("市场格｜价格/状态/路线") and main_source.contains("DistrictSupplyMarketCardPanel") and main_source.contains("DistrictSupplyMarketCardChipRail") and main_source.contains("DistrictSupplyMarketCardColorTick") and main_source.contains("DistrictSupplyPurchaseVerdictRail") and main_source.contains("DistrictSupplyPurchaseVerdictLabel") and main_source.contains("牌面预览｜效果/购买结论"), "district side drawer explains browse-vs-buy with compact board-game market cards")
	_expect(main_source.contains("EconomyDashboardPanel") and main_source.contains("EconomyDashboardKpiGrid") and main_source.contains("EconomyDashboardListCard") and main_source.contains("经济仪表板") and main_source.contains("下方仪表板只显示可扫读信息"), "economy overview opens with a board-game dashboard instead of a long report")
	_expect(main_source.contains("StandingsScoreboardPanel") and main_source.contains("StandingsRaceKpiGrid") and main_source.contains("StandingsPlayerScoreGrid") and main_source.contains("StandingsPlayerScoreCard") and main_source.contains("局势记分板"), "standings page opens with a board-game scoreboard instead of prose rankings")
	_expect(main_source.contains("FinalSettlementBoardPanel") and main_source.contains("FinalSettlementKpiGrid") and main_source.contains("FinalSettlementRankTrack") and main_source.contains("FinalSettlementRankCard") and main_source.contains("FinalSettlementAfterActionGrid"), "final settlement opens with a board-game postgame scoreboard and after-action links")
	_expect(main_source.contains("IntelDossierBoardPanel") and main_source.contains("IntelDossierKpiGrid") and main_source.contains("IntelDossierClueGrid") and main_source.contains("IntelDossierClueCard") and main_source.contains("情报侦探板"), "intel dossier opens with a board-game detective board instead of a long evidence report")
	_expect(main_source.contains("setup_summary_chips") and main_source.contains("setup_seat_card") and main_source.contains("setup_seat_chips") and main_source.contains("NewGameSetupLobbyPanel") and main_source.contains("NewGameSetupFlowTrack") and main_source.contains("NewGameSetupFlowStepCard") and main_source.contains("NewGameSetupSeatIdentityBoard") and main_source.contains("NewGameSetupSeatInfoCard"), "new-game setup uses a board-game lobby flow with setup chips and public seat cards")
	_expect(main_source.contains("menu_continue_button.visible = can_continue and show_main_actions") and main_source.contains("_hide_global_menu_navigation_for_catalog()"), "subpage shell hides global buttons unless a root page explicitly asks for them")
	var hand_index := main_source.find("_add_player_hand_rack(hand_column")
	var tray_index := main_source.find("_add_player_action_tray(tray_column")
	var district_action_index := main_source.find("_add_selected_district_action_panel(action_tray")
	var bid_row_index := main_source.find("_add_bid_control_card(action_tray")
	_expect(hand_index >= 0 and tray_index > hand_index, "hand rack appears before secondary action tray")
	_expect(district_action_index > tray_index and bid_row_index > tray_index, "district actions and bid controls are inside the action tray")
	_expect(main_source.contains("桌边行动托盘") and main_source.contains("避免遮住星球与手牌"), "secondary actions are explicitly contained in a table-edge action tray")
	_expect(main_source.contains("BidControlCard") and main_source.contains("BidControlChipRail") and main_source.contains("公开报价"), "bid controls use a compact public-bid table card")
	_expect(main_source.contains("OwnerGuessCard") and main_source.contains("OwnerGuessChipRail") and main_source.contains("OwnerGuessAvatarRow"), "card-owner guessing uses a dedicated table-side wager card")
	_expect(main_source.contains("资料大厅") and main_source.contains("价格带") and not main_source.contains("价格梯度"), "player-facing menu text remains concise and non-developmental")
	_expect(map_source.contains("PLANET_PROJECTION_BLEND_NAME := \"PlanetProjectionBlend\"") and map_source.contains("func _planet_projection_blend") and map_source.contains("func _projection_smoothstep"), "map projection has an explicit smooth local-to-globe blend contract")
	_expect(map_source.contains("PLANET_PROJECTION_VISIBILITY_FADE_START") and map_source.contains("_projection_visibility_alpha_for_district"), "map projection fades far-side labels and regions during the globe transition")
	_expect(map_source.contains("星球全景｜滚轮贴近") and map_source.contains("拉远中｜地表牌板正在卷成星球") and map_source.contains("局部地表｜滚轮拉远看星球"), "map projection hints use player-facing table language")
	_expect(map_source.contains("projection_contract") and map_source.contains("local_xy_eases_into_center_globe"), "betting table map report exposes the planet projection policy")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("Visual layout contract failure: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Visual layout contract test passed.")
		quit(0)
	else:
		print("Visual layout contract test failed: %s" % " / ".join(_failures))
		quit(1)
