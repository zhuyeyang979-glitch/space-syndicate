extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_contract_document()
	_check_runtime_path_skeleton()
	_check_card_skeleton()
	_check_table_skeleton()
	_check_planet_skeleton()
	_check_main_menu_skeleton()
	_check_submenu_skeleton()
	_finish()


func _check_contract_document() -> void:
	var path := "res://docs/playtest_skeleton_contract.md"
	_expect(FileAccess.file_exists(path), "playtest skeleton contract document exists")
	var source := FileAccess.get_file_as_string(path)
	_expect(_contains_all(source, [
		"途径 / Runtime Path Skeleton",
		"卡面 / Card Skeleton",
		"UI / Table Skeleton",
		"游戏画面 / Planet Skeleton",
		"主菜单 / Main Menu Skeleton",
		"子菜单 / Submenu Skeleton",
	]), "playtest skeleton contract covers runtime path, card, table, planet, main menu, and submenu")


func _check_runtime_path_skeleton() -> void:
	_expect(ResourceLoader.exists("res://scenes/ui/CampaignMenu.tscn"), "campaign menu scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/CampaignBriefing.tscn"), "campaign briefing scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/CampaignRewardPanel.tscn"), "campaign reward scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/MatchRecapPanel.tscn"), "match recap scene exists")
	_expect(FileAccess.file_exists("res://data/campaigns/tutorial_campaign.json"), "tutorial campaign data exists")
	_expect(FileAccess.file_exists("res://data/scenarios/first_table.json"), "first-table runtime fixture exists")
	_expect(FileAccess.file_exists("res://data/scenarios/bid_practice.json"), "bid-practice runtime fixture exists")
	var campaign_test := FileAccess.get_file_as_string("res://tests/campaign_runtime_path_v2_test.gd")
	var privacy_test := FileAccess.get_file_as_string("res://tests/campaign_privacy_test.gd")
	_expect(campaign_test.contains("RuntimeGameScreen") and campaign_test.contains("visual_events"), "campaign runtime test protects real runtime path and visual-events bridge")
	_expect(_contains_all(privacy_test, ["true_owner", "hidden_owner", "owner_truth"]) and _contains_any(privacy_test, ["对手现金", "private_cash", "opponent cash"]), "campaign privacy test protects hidden ownership and private economy")


func _check_card_skeleton() -> void:
	_expect(ResourceLoader.exists("res://scenes/CardUI.tscn"), "legacy/shared CardUI scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/CardFace.tscn"), "split CardFace scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/CardCodexBrowser.tscn"), "card codex browser scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/CardCodexDetail.tscn"), "card codex detail scene exists")
	var card_ui := FileAccess.get_file_as_string("res://scripts/CardUI.gd")
	var card_face := FileAccess.get_file_as_string("res://scripts/ui/card_face.gd")
	var card_art := FileAccess.get_file_as_string("res://scripts/card_art_view.gd")
	var card_browser := FileAccess.get_file_as_string("res://scripts/ui/card_codex_browser.gd")
	var district_market_scene := FileAccess.get_file_as_string("res://scenes/ui/DistrictSupplyMarketCard.tscn")
	var district_market_script := FileAccess.get_file_as_string("res://scripts/ui/district_supply_market_card.gd")
	var detail_snapshot := FileAccess.get_file_as_string("res://scripts/viewmodels/card_codex_detail_snapshot.gd")
	var card_spec := FileAccess.get_file_as_string("res://docs/card_frame_spec.md")
	var visual_contract := FileAccess.get_file_as_string("res://docs/card_visual_theme_contract.md")
	_expect(_contains_all(card_ui, ["PRESENTATION_MINI_HAND", "PRESENTATION_INSPECTOR_FULL", "_render_keyword_chips", "_apply_card_art"]), "CardUI owns mini hand, inspector, keyword, and art skeletons")
	_expect(_contains_all(card_face, ["card_presentation_spec", "CardFace"]) and _contains_all(card_ui, ["mini_hand", "inspector_full", "KeywordChipRail", "CardFaceKeywordChip"]), "CardFace/CardUI keep presentation identity, mini/inspector states, and keyword chips")
	_expect(_contains_all(card_art, ["NIGHT_PATROL_SIGIL_PATH", "NIGHT_PATROL_FRAME_PATHS", "_draw_night_patrol_reference_frame", "_draw_motif"]) and _contains_all(card_browser, ["CardArtViewScript", "CardCodexThumbnailArtView", "shared-card-art-night-patrol-frame"]), "card codex thumbnails share the card-art layer and optional Night Patrol frame/sigil visual theme")
	_expect(_contains_all(district_market_scene, ["DistrictSupplyMarketCardArtHost", "DistrictSupplyMarketCardArtView", "res://scripts/card_art_view.gd"]) and _contains_all(district_market_script, ["_render_market_art", "district_supply_market_uses_shared_card_art", "shared-card-art-market-cell"]), "district supply market cells share the same card-art layer before purchase preview")
	_expect(_contains_all(detail_snapshot, ["codex_full", "upgrades", "resolution", "tactical"]), "card codex detail snapshot carries full card, upgrade, resolution, and tactical skeleton data")
	_expect(_contains_all(card_spec, ["MiniHandCard", "DistrictSupplyMarketCell", "InspectorCard", "CodexDetailCard", "TrackCard"]), "card frame spec defines all card-face skeleton variants")
	_expect(_contains_all(visual_contract, ["同源卡面", "缩略图硬指标", "视觉差异硬指标", "开源素材边界", "玩家阅读顺序"]), "card visual theme contract defines shared card faces, thumbnail hard metrics, visual differentiation, source-asset boundary, and read order")


func _check_table_skeleton() -> void:
	_expect(ResourceLoader.exists("res://scenes/ui/GameScreen.tscn"), "runtime GameScreen scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/PlayerBoard.tscn"), "player board scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/PublicTrack.tscn") or ResourceLoader.exists("res://scenes/ui/CardTrack.tscn"), "public card-track scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/OverlayLayer.tscn"), "overlay layer scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/RightInspector.tscn"), "right inspector scene exists")
	var game_screen := FileAccess.get_file_as_string("res://scenes/ui/GameScreen.tscn")
	var player_board := FileAccess.get_file_as_string("res://scenes/ui/PlayerBoard.tscn")
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/overlay_layer.gd")
	var overlay_scene := FileAccess.get_file_as_string("res://scenes/ui/OverlayLayer.tscn")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(_contains_all(game_screen, ["TopBar", "PublicTrack", "PlanetBoard", "RightInspector", "PlayerBoard", "OverlayLayer"]), "GameScreen has the board-game table skeleton")
	_expect(_contains_all(player_board, ["PlayerResourceTableau", "PlayerHandTableau", "PlayerCommandTableau", "PlayerBidBoard", "HandRack"]), "PlayerBoard has resource, hand, command, bid, and hand-rack skeletons")
	_expect(_contains_all(overlay_scene, ["SideDrawerLayer", "ModalLayer", "DragPreviewLayer"]) and overlay.contains("_dock_confirm_to_planet_side_lane"), "OverlayLayer owns drawer/modal/drag layers and docks temporary decisions to table edge")
	_expect(main_source.contains("_set_planet_right_rail_resolution_suppressed") and main_source.contains("_card_resolution_side_lane_focus_active"), "runtime card-resolution focus can make lower-priority side rails yield")


func _check_planet_skeleton() -> void:
	_expect(ResourceLoader.exists("res://scenes/ui/PlanetBoard.tscn"), "PlanetBoard scene exists")
	var planet_board := FileAccess.get_file_as_string("res://scripts/ui/planet_board.gd")
	var map_view := FileAccess.get_file_as_string("res://scripts/map_view.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(_contains_all(planet_board, ["PlanetStageViewport", "MapHost", "PlanetLeftSpaceRail", "PlanetRightSpaceRail", "PLANET_TABLE_SAFE_CORE_RATIO"]), "PlanetBoard owns stage, map host, side rails, and safe-core metrics")
	_expect(_contains_all(map_view, ["PLANET_PROJECTION_DEFAULT_ZOOM", "reset_to_planet_overview", "zoom_to_local_projection", "visual_layer_focus"]), "MapView keeps globe/local projection and map layer focus skeletons")
	_expect(_contains_all(main_source, ["MapControlBar", "MapLayerFocusRail", "_set_map_layer_focus", "FullscreenMapOverlayScene"]), "runtime map controls expose toolbar, layer focus, and fullscreen skeletons")


func _check_main_menu_skeleton() -> void:
	_expect(ResourceLoader.exists("res://scenes/ui/MenuRootLobby.tscn"), "main menu root lobby scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/NewGameSetupLobby.tscn"), "new game setup lobby scene exists")
	_expect(ResourceLoader.exists("res://scenes/ui/NewGameSetupSeatCard.tscn"), "new game setup seat card scene exists")
	var menu_scene := FileAccess.get_file_as_string("res://scenes/ui/MenuRootLobby.tscn")
	var menu_script := FileAccess.get_file_as_string("res://scripts/ui/menu_root_lobby.gd")
	var setup_scene := FileAccess.get_file_as_string("res://scenes/ui/NewGameSetupLobby.tscn")
	_expect(_contains_all(menu_scene, ["MainMenuPlanetLobbyPanel", "MainMenuPlanetBackdrop", "MainMenuLobbyActionGrid", "MainMenuUtilityRail"]), "main menu is a planet-lobby skeleton, not a raw button list")
	_expect(_contains_all(menu_script, ["MainMenuCommandCard", "MAIN_MENU_FEATURED_CARD_HEIGHT", "action_requested"]), "main menu command cards are scene-rendered and signal-driven")
	_expect(_contains_all(setup_scene, ["NewGameSetupFlowTrack", "NewGameSetupReadinessRail", "NewGameSetupLobbyChipRail"]), "new-game setup owns flow, readiness, and chip skeletons")


func _check_submenu_skeleton() -> void:
	for scene_path in [
		"res://scenes/ui/TutorialQuickStartBoard.tscn",
		"res://scenes/ui/RulesQuickReferenceBoard.tscn",
		"res://scenes/ui/CompendiumHubBoard.tscn",
		"res://scenes/ui/ProductCodexDetail.tscn",
		"res://scenes/ui/BestiaryDetail.tscn",
		"res://scenes/ui/RegionCodexDetail.tscn",
		"res://scenes/ui/EconomyDashboard.tscn",
		"res://scenes/ui/IntelDossierBoard.tscn",
	]:
		_expect(ResourceLoader.exists(scene_path), "%s submenu scene exists" % scene_path)
	var card_browser := FileAccess.get_file_as_string("res://scripts/ui/card_codex_browser.gd")
	var card_detail := FileAccess.get_file_as_string("res://scripts/ui/card_codex_detail.gd")
	var menu_overlay := FileAccess.get_file_as_string("res://scripts/ui/menu_overlay.gd")
	_expect(_contains_all(card_browser, ["thumbnail", "hover", "detail"]) or _contains_all(card_browser, ["CardCodex", "hover", "selected"]), "card codex browser owns thumbnail/hover/detail skeleton")
	_expect(_contains_all(card_detail, ["CardCodexTacticalColorTick", "CardCodexAttributeColorTick", "CardCodexUpgradeLadder"]) or _contains_all(card_detail, ["tactical", "upgrade", "resolution"]), "card codex detail owns tactical/fact/upgrade skeleton")
	_expect(_contains_all(menu_overlay, ["present_menu_shell", "title_label", "body_label", "main_menu_requested", "catalog_back_requested"]), "menu overlay owns local page title/body/back-action skeleton")


func _contains_all(source: String, needles: Array) -> bool:
	for needle_variant in needles:
		if not source.contains(String(needle_variant)):
			return false
	return true


func _contains_any(source: String, needles: Array) -> bool:
	for needle_variant in needles:
		if source.contains(String(needle_variant)):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("Playtest skeleton gate failure: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Playtest skeleton gate passed.")
		quit(0)
	else:
		print("Playtest skeleton gate failed: %s" % " / ".join(_failures))
		quit(1)
