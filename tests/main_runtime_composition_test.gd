extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const GAME_RUNTIME_COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const CARD_RESOLUTION_EXECUTION_BENCH := "res://scenes/tools/CardResolutionExecutionRuntimeCharacterizationBench.tscn"
const CARD_RESOLUTION_EXECUTION_CONTRACT := "res://docs/card_resolution_execution_runtime_contract.md"
const CARD_RESOLUTION_EXECUTION_SERVICE := "res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn"
const CARD_RESOLUTION_EXECUTION_WORLD_BRIDGE := "res://scenes/runtime/CardResolutionExecutionWorldBridge.tscn"
const CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_SERVICE := "res://scenes/runtime/CardEconomyProductRouteEffectRuntimeService.tscn"
const CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_WORLD_BRIDGE := "res://scenes/runtime/CardEconomyProductRouteEffectWorldBridge.tscn"
const CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE := "res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn"
const AI_RUNTIME_CONTROLLER := "res://scenes/runtime/AiRuntimeController.tscn"
const AI_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/AiRuntimeWorldBridge.tscn"
const CARD_PRESENTATION_RUNTIME_SERVICE := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE := "res://scenes/runtime/GameTableViewModelRuntimeService.tscn"
const ACTION_RESULT_PRESENTATION_SERVICE := "res://scenes/runtime/ActionResultPresentationService.tscn"
const CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE := "res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn"
const CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE := "res://scenes/runtime/CardPlayEligibilityWorldBridge.tscn"
const CARD_CODEX_PUBLIC_SOURCE_SERVICE := "res://scenes/runtime/CardCodexPublicSourceService.tscn"
const REGION_CODEX_PUBLIC_SOURCE_SERVICE := "res://scenes/runtime/RegionCodexPublicSourceService.tscn"
const MONSTER_RUNTIME_CONTROLLER := "res://scenes/runtime/MonsterRuntimeController.tscn"
const MONSTER_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/MonsterRuntimeWorldBridge.tscn"
const MONSTER_RUNTIME_CHARACTERIZATION_BENCH := "res://scenes/tools/MonsterRuntimeCharacterizationBench.tscn"
const MONSTER_RUNTIME_CHARACTERIZATION_SCRIPT := "res://scripts/tools/monster_runtime_characterization_bench.gd"
const MONSTER_RUNTIME_OWNERSHIP_CONTRACT := "res://docs/monster_runtime_ownership_contract.md"
const MILITARY_RUNTIME_CHARACTERIZATION_BENCH := "res://scenes/tools/MilitaryRuntimeCharacterizationBench.tscn"
const MILITARY_RUNTIME_CHARACTERIZATION_SCRIPT := "res://scripts/tools/military_runtime_characterization_bench.gd"
const MILITARY_RUNTIME_OWNERSHIP_CONTRACT := "res://docs/military_runtime_ownership_contract.md"
const MILITARY_RUNTIME_CONTROLLER := "res://scenes/runtime/MilitaryRuntimeController.tscn"
const MILITARY_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/MilitaryRuntimeWorldBridge.tscn"
const WEATHER_RUNTIME_CHARACTERIZATION_BENCH := "res://scenes/tools/WeatherRuntimeCharacterizationBench.tscn"
const WEATHER_RUNTIME_CHARACTERIZATION_SCRIPT := "res://scripts/tools/weather_runtime_characterization_bench.gd"
const WEATHER_RUNTIME_OWNERSHIP_CONTRACT := "res://docs/weather_runtime_ownership_contract.md"
const WEATHER_RUNTIME_CONTROLLER := "res://scenes/runtime/WeatherRuntimeController.tscn"
const WEATHER_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/WeatherRuntimeWorldBridge.tscn"
const PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH := "res://scenes/tools/ProductMarketRuntimeCharacterizationBench.tscn"
const PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_SCRIPT := "res://scripts/tools/product_market_runtime_characterization_bench.gd"
const PRODUCT_MARKET_RUNTIME_OWNERSHIP_CONTRACT := "res://docs/product_market_runtime_ownership_contract.md"
const PRODUCT_MARKET_RUNTIME_CONTROLLER := "res://scenes/runtime/ProductMarketRuntimeController.tscn"
const PRODUCT_MARKET_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/ProductMarketRuntimeWorldBridge.tscn"
const CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH := "res://scenes/tools/CityTradeNetworkRuntimeCharacterizationBench.tscn"
const CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_SCRIPT := "res://scripts/tools/city_trade_network_runtime_characterization_bench.gd"
const CITY_TRADE_NETWORK_RUNTIME_OWNERSHIP_CONTRACT := "res://docs/city_trade_network_runtime_ownership_contract.md"
const CITY_TRADE_NETWORK_RUNTIME_CONTROLLER := "res://scenes/runtime/CityTradeNetworkRuntimeController.tscn"
const CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCRIPT := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/CityTradeNetworkWorldBridge.tscn"
const CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCRIPT := "res://scripts/runtime/city_trade_network_world_bridge.gd"
const CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH := "res://scenes/tools/CityDevelopmentSettlementRuntimeCharacterizationBench.tscn"
const CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_SCRIPT := "res://scripts/tools/city_development_settlement_runtime_characterization_bench.gd"
const CITY_DEVELOPMENT_SETTLEMENT_CONTRACT := "res://docs/city_development_settlement_runtime_contract.md"
const CITY_DEVELOPMENT_RUNTIME_CONTROLLER := "res://scenes/runtime/CityDevelopmentRuntimeController.tscn"
const CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCRIPT := "res://scripts/runtime/city_development_runtime_controller.gd"
const CITY_DEVELOPMENT_WORLD_BRIDGE := "res://scenes/runtime/CityDevelopmentWorldBridge.tscn"
const CITY_DEVELOPMENT_WORLD_BRIDGE_SCRIPT := "res://scripts/runtime/city_development_world_bridge.gd"
const CITY_GDP_DERIVATIVE_RUNTIME_BENCH := "res://scenes/tools/CityGdpDerivativeRuntimeBench.tscn"
const CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER := "res://scenes/runtime/CityGdpDerivativeRuntimeController.tscn"
const CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/CityGdpDerivativeRuntimeWorldBridge.tscn"
const CITY_GDP_DERIVATIVE_TERMS_CONTRACT := "res://docs/city_gdp_derivative_v04_terms_contract.md"
const RUNTIME_CARD_CATALOG_RESOURCE_BENCH := "res://scenes/tools/RuntimeCardCatalogResourceBench.tscn"
const RUNTIME_CARD_CATALOG_RESOURCE_SCRIPT := "res://scripts/tools/runtime_card_catalog_resource_bench.gd"
const CARD_RUNTIME_CATALOG_SERVICE := "res://scenes/runtime/CardRuntimeCatalogService.tscn"
const CARD_RUNTIME_DEFINITION_WORLD_BRIDGE := "res://scenes/runtime/CardRuntimeDefinitionWorldBridge.tscn"
const GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE := "res://scenes/runtime/GameplayBalanceDiagnosticsRuntimeService.tscn"
const GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE := "res://scenes/runtime/GameplayBalanceDiagnosticsWorldBridge.tscn"
const DEVELOPMENT_ROUTE_CATALOG := "res://resources/balance/development_route_catalog_v04.tres"
const CARD_RUNTIME_CATALOG_RESOURCE := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const CARD_RUNTIME_CATALOG_INTEGRITY := "res://tests/fixtures/runtime_card_catalog_v04_integrity.json"
const RUNTIME_CARD_CATALOG_OWNERSHIP_CONTRACT := "res://docs/runtime_card_catalog_ownership_contract.md"
const RUNTIME_CARD_CATALOG_RESOURCE_SCHEMA := "res://docs/runtime_card_catalog_resource_schema.md"
const RUNTIME_CARD_AUTHORING_WORKSPACE := "res://scenes/tools/RuntimeCardAuthoringWorkspace.tscn"
const RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH := "res://scenes/tools/RuntimeCardAuthoringWorkflowBench.tscn"
const RUNTIME_CARD_AUTHORING_SERVICE := "res://scripts/cards/card_runtime_authoring_service.gd"
const RUNTIME_CARD_AUTHORING_INSPECTOR_PLUGIN := "res://addons/space_syndicate_design_qa/card_runtime_authoring_inspector_plugin.gd"
const RUNTIME_CARD_AUTHORING_WORKFLOW_DOC := "res://docs/runtime_card_authoring_workflow.md"
const RULESET_V05_PROFILE := "res://resources/rules/space_syndicate_ruleset_v05.tres"
const PRODUCT_INDUSTRY_CATALOG_V05 := "res://resources/content/product_industry_catalog_v05.tres"
const CARD_RUNTIME_CATALOG_V05 := "res://resources/cards/runtime/card_runtime_catalog_v05.tres"
const CLOCK_DOMAIN_REGISTRY_V05 := "res://resources/rules/clock_domain_registry_v05.tres"
const RULESET_SAVE_HANDSHAKE_V05 := "res://scenes/runtime/RulesetSaveHandshakeService.tscn"
const RULESET_V05_FOUNDATION_BENCH := "res://scenes/tools/RulesetV05FoundationBench.tscn"
const PLAYER_TEXT_V05_SCHEMA := "res://resources/localization/player_text_schema_v05.tres"
const PLAYER_TEXT_V05_UNIT_CATALOG := "res://resources/localization/unit_display_catalog_v05.tres"
const PLAYER_TEXT_V05_TRANSLATION := "res://localization/v05/player_text_zh_Hans.po"
const PLAYER_TEXT_V05_MIGRATION_REGISTRY := "res://resources/migrations/card_text_v04_to_v05_registry.tres"
const PLAYER_TEXT_V05_FOUNDATION_BENCH := "res://scenes/tools/PlayerTextV05FoundationBench.tscn"
const VICTORY_CONTROL_RUNTIME_CONTROLLER := "res://scenes/runtime/VictoryControlRuntimeController.tscn"
const VICTORY_CONTROL_WORLD_BRIDGE := "res://scenes/runtime/VictoryControlWorldBridge.tscn"
const VICTORY_CONTROL_RUNTIME_BENCH := "res://scenes/tools/VictoryControlRuntimeBench.tscn"
const VICTORY_CONTROL_RUNTIME_CONTRACT := "res://docs/victory_control_runtime_contract.md"
const INDUSTRY_CAPACITY_RUNTIME_SERVICE := "res://scenes/runtime/IndustryCapacityRuntimeService.tscn"
const INDUSTRY_CAPACITY_WORLD_BRIDGE := "res://scenes/runtime/IndustryCapacityWorldBridge.tscn"
const INDUSTRY_CAPACITY_CARD_GROUP_RUNTIME_BENCH := "res://scenes/tools/IndustryCapacityCardGroupRuntimeBench.tscn"
const INDUSTRY_CAPACITY_CARD_GROUP_RUNTIME_CONTRACT := "res://docs/industry_capacity_card_group_runtime_contract.md"
const RULESET_V06_PROFILE := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const RULESET_V06_SCHEMA_REGISTRY := "res://scripts/rules/ruleset_v06_schema_registry.gd"
const RULESET_V06_CONFORMANCE_REGISTRY := "res://scripts/tools/ruleset_v06_conformance_registry.gd"
const REGION_INFRASTRUCTURE_CHARACTERIZATION_BENCH := "res://scenes/tools/RegionInfrastructureRuntimeCharacterizationBench.tscn"
const REGION_INFRASTRUCTURE_CHARACTERIZATION_REGISTRY := "res://scripts/tools/region_infrastructure_characterization_registry.gd"
const REGION_INFRASTRUCTURE_CONTRACT := "res://docs/region_infrastructure_runtime_ownership_contract.md"
const REGION_INFRASTRUCTURE_RUNTIME_CONTROLLER := "res://scenes/runtime/RegionInfrastructureRuntimeController.tscn"
const REGION_INFRASTRUCTURE_WORLD_BRIDGE := "res://scenes/runtime/RegionInfrastructureWorldBridge.tscn"
const ROUTE_NETWORK_RUNTIME_CONTROLLER := "res://scenes/runtime/RouteNetworkRuntimeController.tscn"
const ROUTE_NETWORK_WORLD_BRIDGE := "res://scenes/runtime/RouteNetworkWorldBridge.tscn"
const COMMODITY_FLOW_RUNTIME_CONTROLLER := "res://scenes/runtime/CommodityFlowRuntimeController.tscn"
const COMMODITY_FLOW_WORLD_BRIDGE := "res://scenes/runtime/CommodityFlowWorldBridge.tscn"
const COMMODITY_FLOW_POSTCOMMIT_CONSUMER := "res://scenes/runtime/CommodityFlowPostCommitReceiptConsumer.tscn"
const REGION_SUPPLY_RUNTIME_CONTROLLER := "res://scenes/runtime/RegionSupplyRuntimeController.tscn"
const PLAYER_MANA_RUNTIME_CONTROLLER := "res://scenes/runtime/PlayerManaRuntimeController.tscn"
const COMMODITY_CARD_INVENTORY_RUNTIME_CONTROLLER := "res://scenes/runtime/CommodityCardInventoryRuntimeController.tscn"
const PLANET_MAP_VIEW_SCENE := "res://scenes/ui/PlanetMapView.tscn"
const PLANET_SOLAR_CAMERA_CONTROLLER := "res://scenes/ui/map/PlanetSolarCameraController.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main.tscn loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate() as Control
	_expect(main != null, "main.tscn instantiates")
	if main == null:
		_finish()
		return
	_check_static_composition(main)
	_check_product_market_characterization_assets()
	_check_city_trade_network_characterization_assets()
	_check_city_development_settlement_characterization_assets()
	_check_city_gdp_derivative_assets()
	_check_runtime_card_catalog_resource_assets()
	_check_runtime_card_authoring_assets()
	_check_ruleset_v05_foundation_assets()
	_check_player_text_v05_foundation_assets()
	_check_victory_control_runtime_assets()
	_check_industry_capacity_card_group_runtime_assets()
	_check_ruleset_v06_region_infrastructure_foundation_assets()
	var test_bgm := main.get_node_or_null("RuntimeServices/TableAudioHost/NightPatrolTableBgm") as AudioStreamPlayer
	if test_bgm != null:
		test_bgm.stream = null
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	_check_runtime_snapshot(main, "initial bind")
	_check_runtime_controller_authority(main)
	_check_runtime_signal_bindings(main)
	main.call("_build_layout")
	main.call("_build_layout")
	await process_frame
	_check_runtime_snapshot(main, "repeated bind")
	_check_runtime_signal_bindings(main)
	for player_variant in main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	packed = null
	_finish()


func _check_static_composition(main: Control) -> void:
	for node_path in [
		"RuntimeGameScreen",
		"RuntimeServices",
		"RuntimeServices/RulesetRuntimeBridge",
		"RuntimeServices/FinalSettlementRuntimeComposition",
		"RuntimeServices/DeveloperBalanceApplicationHost",
		"RuntimeServices/TableAudioHost",
		"RuntimeServices/RuntimeControllerHost",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionFrameDriver",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionTransitionSink",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCooldownRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/VisualCueRuntimeOwner",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/TablePresentationRefreshScheduler",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardRuntimeCatalogService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardRuntimeDefinitionWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPresentationRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameTableViewModelRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayEligibilityRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayEligibilityWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ForcedDecisionRuntimeScheduler",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardInventoryRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ActionResultPresentationService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseSettlementRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplySnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplyViewerQueryPort",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplyRuntimeQueryPort",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplyActionPort",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardTargetChoiceResponseSink",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterWagerResponseSink",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RouteNetworkRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RouteNetworkWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityFlowRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityFlowWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/PlayerManaRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityCardInventoryRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayerStateProductionAdapterV06",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CoreEconomicCardRuntimeAdapterV06",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionInfrastructureRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionInfrastructureWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/VictoryControlRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/VictoryControlWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSourceService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSourceService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSourceService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionCodexPublicSourceService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyDashboardPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/StandingsPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FinalSettlementPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/IntelDossierPublicSnapshotService",
		"RuntimeServices/RuntimeFallbackHost",
	]:
		_expect(main.get_node_or_null(node_path) != null, "main.tscn owns %s" % node_path)
	var screen := main.get_node_or_null("RuntimeGameScreen") as Control
	_expect(screen != null and screen.scene_file_path == "res://scenes/ui/GameScreen.tscn", "RuntimeGameScreen is the editable GameScreen scene instance")
	for node_name in ["TopBar", "PlanetBoard", "PlanetMapView", "RightInspector", "PlayerBoard", "OverlayLayer"]:
		_expect(screen != null and screen.find_child(node_name, true, false) != null, "RuntimeGameScreen contains %s" % node_name)
	var commodity_tracks := screen.find_children("TopCommoditySushiTrack", "PanelContainer", true, false) if screen != null else []
	var retired_public_tracks := screen.find_children("PublicTrack", "", true, false) if screen != null else []
	var retired_focus_ribbons := screen.find_children("TrackFocusRibbon", "", true, false) if screen != null else []
	_expect(commodity_tracks.size() == 1 and (commodity_tracks[0] as Node).scene_file_path == "res://scenes/ui/table/TopCommoditySushiTrack.tscn", "RuntimeGameScreen owns exactly one formal TopCommoditySushiTrack scene")
	_expect(retired_public_tracks.is_empty() and retired_focus_ribbons.is_empty(), "RuntimeGameScreen owns zero retired persistent card-track nodes")
	for node_name in ["FullscreenMapOverlay", "FullscreenPlanetMapView", "PlanetMapControlToolbar", "CardResolutionTableBannerOverlay", "BottomCountdownOverlay", "DistrictSupplySideDrawerOverlay", "MenuModalOverlay"]:
		var node := screen.find_child(node_name, true, false) as Control if screen != null else null
		_expect(node != null, "OverlayLayer owns %s" % node_name)
		if node != null and node_name not in ["FullscreenPlanetMapView", "PlanetMapControlToolbar"]:
			_expect(not node.visible, "%s starts hidden in the editable scene" % node_name)
	var district_supply_drawer := screen.find_child("DistrictSupplySideDrawerOverlay", true, false) as Control if screen != null else null
	_expect(district_supply_drawer != null and district_supply_drawer.scene_file_path == "res://scenes/ui/DistrictSupplyDrawer.tscn", "OverlayLayer owns the editable DistrictSupplyDrawer scene instance")
	_expect(district_supply_drawer != null and district_supply_drawer.has_method("set_supply") and district_supply_drawer.has_method("clear_supply") and district_supply_drawer.has_method("debug_snapshot") and district_supply_drawer.has_signal("supply_action_requested"), "DistrictSupplyDrawer owns its pure snapshot and aggregate action boundary")
	for drawer_node_name in ["DistrictPurchaseWindowStatus", "DistrictSupplyShelfChipRail", "DistrictSupplyMarketStatusRail", "DistrictSupplyPrivacyHint", "DistrictSupplyMarketGrid", "DistrictSupplyMarketEmptyState", "DistrictSupplyPreviewBox", "DistrictSupplyPreviewEmptyState"]:
		_expect(district_supply_drawer != null and district_supply_drawer.find_child(drawer_node_name, true, false) != null, "DistrictSupplyDrawer statically owns %s" % drawer_node_name)
	_expect(main.get_node_or_null("LegacyRuntimeTable") == null, "LegacyRuntimeTable is retired from the editable main composition")
	var ruleset_bridge := main.get_node_or_null("RuntimeServices/RulesetRuntimeBridge")
	_expect(ruleset_bridge != null and ruleset_bridge.scene_file_path == "res://scenes/runtime/RulesetRuntimeBridge.tscn", "RuntimeServices owns the editable RulesetRuntimeBridge scene")
	_expect(ruleset_bridge != null and ruleset_bridge.has_method("timing_rules") and ruleset_bridge.has_method("capability_rules") and ruleset_bridge.has_method("card_inventory_rules") and ruleset_bridge.has_method("debug_snapshot"), "RulesetRuntimeBridge exposes pure-data runtime APIs including card inventory policy")
	var card_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionRuntimeController")
	_expect(card_controller != null and card_controller.scene_file_path == "res://scenes/runtime/CardResolutionRuntimeController.tscn", "GameRuntimeCoordinator owns the editable CardResolutionRuntimeController scene")
	_expect(card_controller != null and card_controller.has_method("tick") and card_controller.has_method("to_save_data") and card_controller.has_method("debug_snapshot"), "CardResolutionRuntimeController exposes timing, save, and debug APIs")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var solar_availability := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/SolarAvailabilityRuntimeService")
	var final_settlement_composition := main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition")
	var developer_balance_host := main.get_node_or_null("RuntimeServices/DeveloperBalanceApplicationHost") as DeveloperBalanceApplicationHost
	var region_infrastructure := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionInfrastructureRuntimeController")
	var region_infrastructure_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionInfrastructureWorldBridge")
	_expect(region_infrastructure != null and region_infrastructure.scene_file_path == REGION_INFRASTRUCTURE_RUNTIME_CONTROLLER and region_infrastructure.has_method("apply_facility_action") and region_infrastructure.has_method("rollback_facility_action") and region_infrastructure.has_method("finalize_facility_action") and region_infrastructure.has_method("facility_rollback_atomic_ready"), "GameRuntimeCoordinator owns the authoritative v0.6 RegionInfrastructure facility lifecycle")
	_expect(region_infrastructure_bridge != null and region_infrastructure_bridge.scene_file_path == REGION_INFRASTRUCTURE_WORLD_BRIDGE and region_infrastructure_bridge.has_method("bind_world") and region_infrastructure_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-owning RegionInfrastructureWorldBridge")
	var balance_diagnostics := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsRuntimeService")
	var balance_diagnostics_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsWorldBridge")
	var ai_runtime_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	var ai_runtime_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeWorldBridge")
	var ai_session_public_query := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiSessionPublicQueryPort")
	var ai_card_hand_query := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiCardHandQueryPort")
	var ai_card_eligibility_query := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiCardEligibilityQueryPort")
	var card_presentation := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPresentationRuntimeService")
	var table_viewmodel := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameTableViewModelRuntimeService")
	var card_play_eligibility := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayEligibilityRuntimeService")
	var card_play_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayEligibilityWorldBridge")
	var scheduler := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ForcedDecisionRuntimeScheduler")
	var session := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController")
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	var purchase := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseRuntimeController")
	var card_inventory := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardInventoryRuntimeService")
	var card_resolution_queue := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService")
	var action_result_presentation := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ActionResultPresentationService")
	var card_resolution_execution := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService")
	var card_resolution_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionWorldBridge")
	var economy_product_route_effect := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectRuntimeService")
	var economy_product_route_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectWorldBridge")
	var economy_product_route_formula := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService")
	var product_market_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	var product_market_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeWorldBridge")
	var city_gdp_derivative_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityGdpDerivativeRuntimeController")
	var city_gdp_derivative_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityGdpDerivativeRuntimeWorldBridge")
	var route_network := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RouteNetworkRuntimeController")
	var route_network_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RouteNetworkWorldBridge")
	var commodity_flow := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityFlowRuntimeController")
	var commodity_postcommit := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityFlowPostCommitReceiptConsumer")
	var commodity_flow_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityFlowWorldBridge")
	var region_supply := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionSupplyRuntimeController")
	var player_mana := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/PlayerManaRuntimeController")
	var commodity_inventory := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CommodityCardInventoryRuntimeController")
	var production_state_adapter := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayerStateProductionAdapterV06")
	var core_economic_adapter := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CoreEconomicCardRuntimeAdapterV06")
	var hand_interaction := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/PlayerHandInteractionRuntimeService")
	var purchase_settlement := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseSettlementRuntimeService")
	var district_supply_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplySnapshotService")
	var district_supply_query := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplyViewerQueryPort")
	var district_supply_runtime_query := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplyRuntimeQueryPort")
	var district_supply_action := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplyActionPort")
	var card_target_choice_response_sink := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardTargetChoiceResponseSink")
	var monster_wager_response_sink := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterWagerResponseSink")
	var codex_navigation := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController")
	var codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexPublicSnapshotService")
	var monster_codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSnapshotService")
	var monster_codex_public_source := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSourceService")
	var product_codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSnapshotService")
	var product_codex_public_source := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSourceService")
	var card_codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSnapshotService")
	var card_codex_public_source := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSourceService")
	var region_codex_public_source := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionCodexPublicSourceService")
	var economy_dashboard_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyDashboardPublicSnapshotService")
	var standings_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/StandingsPublicSnapshotService")
	var final_settlement_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FinalSettlementPublicSnapshotService")
	var intel_dossier_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/IntelDossierPublicSnapshotService")
	_expect(coordinator != null and coordinator.scene_file_path == "res://scenes/runtime/GameRuntimeCoordinator.tscn" and coordinator.has_method("active_forced_decision") and coordinator.has_method("debug_snapshot"), "RuntimeControllerHost owns the editable GameRuntimeCoordinator scene")
	_expect(coordinator != null and coordinator.has_method("solar_public_presentation_snapshot") and solar_availability != null and solar_availability.has_method("public_presentation_snapshot") and not solar_availability.has_method("to_save_data") and not solar_availability.has_method("apply_save_data"), "Coordinator exposes the allowlisted solar presentation projection without a second save owner")
	var embedded_map := screen.find_child("PlanetMapView", true, false) as Control if screen != null else null
	var solar_camera := embedded_map.get_node_or_null("PlanetSolarCameraController") if embedded_map != null else null
	_expect(embedded_map != null and embedded_map.scene_file_path == PLANET_MAP_VIEW_SCENE and solar_camera != null and solar_camera.scene_file_path == PLANET_SOLAR_CAMERA_CONTROLLER and solar_camera.has_method("apply_public_solar_snapshot") and solar_camera.has_method("request_return_to_sun") and not solar_camera.has_method("to_save_data") and not solar_camera.has_method("apply_save_data"), "PlanetMapView statically owns the non-saving solar camera presentation controller")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for retired_cadence_symbol in ["var ui_timer", "var ui_map_refresh_timer", "var ui_full_refresh_timer", "var developer_balance_refresh_timer", "func _update_process_ui_refresh"]:
		_expect(not main_source.contains(retired_cadence_symbol), "presentation cadence cutover retires main.gd symbol: %s" % retired_cadence_symbol)
	_expect(not main_source.contains("func _set_map_view_data") and coordinator.has_method("advance_table_presentation") and coordinator.get_node_or_null("TablePresentationSourceOwner") != null and coordinator.get_node_or_null("TablePresentationRefreshPort") != null, "scene-owned presentation source and port replace Main map injection")
	_expect(balance_diagnostics != null and balance_diagnostics.scene_file_path == GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE and balance_diagnostics.has_method("development_routes") and balance_diagnostics.has_method("card_budget_report") and balance_diagnostics.has_method("build_balance_report") and balance_diagnostics.has_method("build_developer_panel_snapshot"), "GameRuntimeCoordinator owns the read-only GameplayBalanceDiagnosticsRuntimeService scene")
	_expect(balance_diagnostics_world_bridge != null and balance_diagnostics_world_bridge.scene_file_path == GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE and balance_diagnostics_world_bridge.has_method("bind_world") and balance_diagnostics_world_bridge.has_method("build_world_snapshot") and balance_diagnostics_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-mutating GameplayBalanceDiagnosticsWorldBridge scene")
	var diagnostics_debug: Dictionary = balance_diagnostics.call("debug_snapshot") if balance_diagnostics != null else {}
	_expect(int(diagnostics_debug.get("route_count", 0)) == 7 and str(diagnostics_debug.get("runtime_balance_model_owner", "")) == "res://scripts/balance/runtime_balance_model.gd" and not bool(diagnostics_debug.get("formula_authority", true)) and not bool(diagnostics_debug.get("world_mutation_authority", true)), "diagnostics service uses seven route Resources while RuntimeBalanceModel remains formula owner")
	var route_catalog := load(DEVELOPMENT_ROUTE_CATALOG)
	var route_validation: Dictionary = route_catalog.call("validation_report") if route_catalog != null and route_catalog.has_method("validation_report") else {}
	_expect(bool(route_validation.get("valid", false)) and int(route_validation.get("route_count", 0)) == 7, "v0.4 Development Route Catalog is valid and Inspector editable")
	_expect(ai_runtime_controller != null and ai_runtime_controller.scene_file_path == AI_RUNTIME_CONTROLLER and ai_runtime_controller.has_method("build_turn_plan") and ai_runtime_controller.has_method("build_response_plan") and ai_runtime_controller.has_method("to_save_data") and ai_runtime_controller.has_method("policy_snapshot"), "GameRuntimeCoordinator owns the authoritative AiRuntimeController scene")
	_expect(ai_session_public_query != null and ai_session_public_query.scene_file_path == "res://scenes/runtime/AiSessionPublicQueryPort.tscn" and ai_session_public_query.has_method("public_snapshot") and not ai_session_public_query.has_method("to_save_data"), "GameRuntimeCoordinator owns one non-owning AI session public query port")
	_expect(ai_card_hand_query != null and ai_card_hand_query.scene_file_path == "res://scenes/runtime/AiCardHandQueryPort.tscn" and ai_card_hand_query.has_method("private_hand_snapshot") and ai_card_hand_query.has_method("bind_ai_capabilities") and not ai_card_hand_query.has_method("to_save_data"), "GameRuntimeCoordinator owns one actor-scoped non-owning AI card-hand query port")
	_expect(ai_card_eligibility_query != null and ai_card_eligibility_query.scene_file_path == "res://scenes/runtime/AiCardEligibilityQueryPort.tscn" and ai_card_eligibility_query.has_method("eligibility_snapshot") and ai_card_eligibility_query.has_method("requirement_snapshot") and ai_card_eligibility_query.has_method("best_share_snapshot") and ai_card_eligibility_query.has_method("bind_ai_capabilities") and not ai_card_eligibility_query.has_method("to_save_data"), "GameRuntimeCoordinator owns one actor-scoped non-owning AI card-eligibility query port")
	_expect(ai_runtime_world_bridge != null and ai_runtime_world_bridge.scene_file_path == AI_RUNTIME_WORLD_BRIDGE and ai_runtime_world_bridge.has_method("bind_world") and ai_runtime_world_bridge.has_method("route_intent") and ai_runtime_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the stateless AiRuntimeWorldBridge scene")
	_expect(card_presentation != null and card_presentation.scene_file_path == CARD_PRESENTATION_RUNTIME_SERVICE and card_presentation.has_method("compose_card") and card_presentation.has_method("compose_hand_card") and card_presentation.has_method("compose_resolution") and card_presentation.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the authoritative CardPresentationRuntimeService scene")
	_expect(table_viewmodel != null and table_viewmodel.scene_file_path == GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE and table_viewmodel.has_method("compose_table") and table_viewmodel.has_method("compose_card_surfaces") and table_viewmodel.has_method("compose_resolution_overlay_badges") and table_viewmodel.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the authoritative GameTableViewModelRuntimeService scene")
	_expect(card_play_eligibility != null and card_play_eligibility.scene_file_path == CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE and card_play_eligibility.has_method("evaluate_play") and card_play_eligibility.has_method("evaluate_hand") and card_play_eligibility.has_method("requirement_status") and card_play_eligibility.has_method("target_status"), "GameRuntimeCoordinator owns the authoritative CardPlayEligibilityRuntimeService scene")
	_expect(card_play_world_bridge != null and card_play_world_bridge.scene_file_path == CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE and card_play_world_bridge.has_method("build_facts") and card_play_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the read-only CardPlayEligibilityWorldBridge scene")
	_expect(scheduler != null and scheduler.scene_file_path == "res://scenes/runtime/ForcedDecisionRuntimeScheduler.tscn" and scheduler.has_method("active_decision") and scheduler.has_method("blocks_card_resolution"), "GameRuntimeCoordinator owns the editable ForcedDecisionRuntimeScheduler scene")
	_expect(session != null and session.scene_file_path == "res://scenes/runtime/GameSessionRuntimeController.tscn" and session.has_method("begin_session") and session.has_method("request_save") and session.has_method("request_load"), "GameRuntimeCoordinator owns the editable GameSessionRuntimeController scene")
	_expect(save != null and save.scene_file_path == "res://scenes/runtime/GameSaveRuntimeCoordinator.tscn" and save.has_method("write_save") and save.has_method("read_save") and save.has_method("operation_snapshot"), "GameSessionRuntimeController owns the editable GameSaveRuntimeCoordinator scene")
	_expect(purchase != null and purchase.scene_file_path == "res://scenes/runtime/DistrictPurchaseRuntimeController.tscn" and purchase.has_method("open_window") and purchase.has_method("attach_quote") and purchase.has_method("active_quote") and purchase.has_method("to_legacy_save_snapshot") and not purchase.has_method("authorize_purchase") and not purchase.has_method("tick_window"), "GameRuntimeCoordinator owns the session-only DistrictPurchaseRuntimeController without legacy pricing or timer wrappers")
	_expect(card_inventory != null and card_inventory.scene_file_path == "res://scenes/runtime/CardInventoryRuntimeService.tscn" and card_inventory.has_method("plan_receive") and card_inventory.has_method("commit_receive") and card_inventory.has_method("plan_remove") and card_inventory.has_method("commit_remove") and card_inventory.has_method("plan_lock") and card_inventory.has_method("commit_lock") and card_inventory.has_method("plan_transfer") and card_inventory.has_method("commit_transfer") and card_inventory.has_method("inventory_fingerprint"), "GameRuntimeCoordinator owns the editable CardInventoryRuntimeService scene and complete slot-mutation API")
	_expect(card_resolution_queue != null and card_resolution_queue.scene_file_path == "res://scenes/runtime/CardResolutionQueueRuntimeService.tscn" and card_resolution_queue.has_method("plan_submission") and card_resolution_queue.has_method("commit_submission") and card_resolution_queue.has_method("lock_batch") and card_resolution_queue.has_method("start_next") and card_resolution_queue.has_method("complete_active") and card_resolution_queue.has_method("promote_next_batch") and card_resolution_queue.has_method("to_legacy_save_snapshot") and card_resolution_queue.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable CardResolutionQueueRuntimeService scene and complete queue-lifecycle API")
	_expect(action_result_presentation != null and action_result_presentation.scene_file_path == ACTION_RESULT_PRESENTATION_SERVICE and action_result_presentation.has_method("compose") and action_result_presentation.has_method("public_field_schema") and action_result_presentation.has_method("debug_snapshot") and not action_result_presentation.has_method("to_save_data") and not action_result_presentation.has_method("apply_save_data"), "GameRuntimeCoordinator statically composes one non-owning ActionResult presentation service")
	_expect(coordinator != null and coordinator.has_method("compose_action_result_v1") and coordinator.find_children("ActionResultPresentationService", "", true, false).size() == 1, "Coordinator exposes one thin ActionResult v1 proxy and one scene instance")
	_expect(card_resolution_execution != null and card_resolution_execution.scene_file_path == CARD_RESOLUTION_EXECUTION_SERVICE and card_resolution_execution.has_method("plan_execution") and card_resolution_execution.has_method("advance_execution") and card_resolution_execution.has_method("finalize_execution") and card_resolution_execution.has_method("recover_from_active") and card_resolution_execution.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable CardResolutionExecutionRuntimeService scene and execution-transaction API")
	_expect(card_resolution_world_bridge != null and card_resolution_world_bridge.scene_file_path == CARD_RESOLUTION_EXECUTION_WORLD_BRIDGE and card_resolution_world_bridge.has_method("apply_intent") and card_resolution_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the stateless CardResolutionExecutionWorldBridge scene")
	_expect(economy_product_route_effect != null and economy_product_route_effect.scene_file_path == CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_SERVICE and economy_product_route_effect.has_method("supports_handler") and economy_product_route_effect.has_method("plan_effect") and economy_product_route_effect.has_method("finalize_effect") and economy_product_route_effect.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable economy/product/route effect-family service")
	_expect(economy_product_route_bridge != null and economy_product_route_bridge.scene_file_path == CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_WORLD_BRIDGE and economy_product_route_bridge.has_method("apply_effect") and economy_product_route_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the stateless economy/product/route world bridge")
	_expect(economy_product_route_formula != null and economy_product_route_formula.scene_file_path == CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE and economy_product_route_formula.has_method("supported_formulas") and economy_product_route_formula.has_method("calculate") and economy_product_route_formula.has_method("formula_ownership_snapshot") and economy_product_route_formula.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable pure economy/product/route Formula Service")
	_expect(product_market_controller != null and product_market_controller.scene_file_path == PRODUCT_MARKET_RUNTIME_CONTROLLER and product_market_controller.has_method("refresh_prices") and product_market_controller.has_method("market_tick") and product_market_controller.has_method("terms_for_card_id") and product_market_controller.has_method("open_futures_position") and product_market_controller.has_method("settle_futures_for_destroyed_warehouse") and product_market_controller.has_method("to_save_data") and product_market_controller.has_method("apply_save_data"), "GameRuntimeCoordinator owns the authoritative Resource-backed ProductMarketRuntimeController scene")
	_expect(product_market_world_bridge != null and product_market_world_bridge.scene_file_path == PRODUCT_MARKET_RUNTIME_WORLD_BRIDGE and product_market_world_bridge.has_method("bind_world") and product_market_world_bridge.has_method("shared_rng") and product_market_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-owning ProductMarketRuntimeWorldBridge scene")
	_expect(not FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd").contains("_add_panic"), "ProductMarket speculation no longer routes the retired Main panic state")
	_expect(city_gdp_derivative_controller != null and city_gdp_derivative_controller.scene_file_path == CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER and city_gdp_derivative_controller.has_method("open_position") and city_gdp_derivative_controller.has_method("settle_district") and city_gdp_derivative_controller.has_method("settle_destroyed_city") and city_gdp_derivative_controller.has_method("to_save_data") and city_gdp_derivative_controller.has_method("apply_save_data"), "GameRuntimeCoordinator owns the authoritative Resource-backed CityGdpDerivativeRuntimeController scene")
	_expect(city_gdp_derivative_world_bridge != null and city_gdp_derivative_world_bridge.scene_file_path == CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE and city_gdp_derivative_world_bridge.has_method("bind_world") and city_gdp_derivative_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-owning CityGdpDerivativeRuntimeWorldBridge scene")
	_expect(route_network != null and route_network.scene_file_path == ROUTE_NETWORK_RUNTIME_CONTROLLER and route_network.has_method("refresh_routes") and route_network.has_method("to_save_data") and route_network.has_method("apply_save_data"), "GameRuntimeCoordinator owns the authoritative v0.6 RouteNetworkRuntimeController")
	_expect(route_network_bridge != null and route_network_bridge.scene_file_path == ROUTE_NETWORK_WORLD_BRIDGE and route_network_bridge.has_method("bind_world") and route_network_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-owning RouteNetworkWorldBridge")
	_expect(commodity_flow != null and commodity_flow.scene_file_path == COMMODITY_FLOW_RUNTIME_CONTROLLER and commodity_flow.has_method("install_commodity") and commodity_flow.has_method("advance_world") and commodity_flow.has_method("card_effect_candidates_snapshot") and commodity_flow.has_method("to_save_data"), "GameRuntimeCoordinator owns the authoritative v0.6 CommodityFlowRuntimeController")
	_expect(commodity_postcommit != null and commodity_postcommit.scene_file_path == COMMODITY_FLOW_POSTCOMMIT_CONSUMER and commodity_postcommit.has_method("consume_committed_batch") and commodity_postcommit.has_method("retry_pending_batch") and commodity_postcommit.has_method("to_save_data"), "GameRuntimeCoordinator owns one scene-owned CommodityFlow post-commit exact-once consumer")
	_expect(commodity_flow_bridge != null and commodity_flow_bridge.scene_file_path == COMMODITY_FLOW_WORLD_BRIDGE and not commodity_flow_bridge.has_method("bind_world") and not commodity_flow_bridge.has_method("notify_sale_receipt_batch_committed") and commodity_flow_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns a non-owning CommodityFlowWorldBridge with no Main callback capability")
	_expect(region_supply != null and region_supply.scene_file_path == REGION_SUPPLY_RUNTIME_CONTROLLER and region_supply.has_method("configure") and region_supply.has_method("public_rack_snapshot") and region_supply.has_method("prepare_slot_refill") and region_supply.has_method("commit_slot_refill") and region_supply.has_method("rollback_slot_refill") and region_supply.has_method("finalize_slot_refill") and region_supply.has_method("to_save_data") and region_supply.has_method("apply_save_data"), "GameRuntimeCoordinator owns the authoritative deterministic RegionSupplyRuntimeController")
	_expect(player_mana != null and player_mana.scene_file_path == PLAYER_MANA_RUNTIME_CONTROLLER and player_mana.has_method("advance") and player_mana.has_method("commit_reservation") and player_mana.has_method("to_save_data"), "GameRuntimeCoordinator owns the single v0.6 six-color asset owner")
	_expect(commodity_inventory != null and commodity_inventory.scene_file_path == COMMODITY_CARD_INVENTORY_RUNTIME_CONTROLLER and commodity_inventory.has_method("configure_market") and commodity_inventory.has_method("purchase_market_card") and commodity_inventory.has_method("play_core_card") and commodity_inventory.has_method("player_snapshot"), "GameRuntimeCoordinator owns the single v0.6 card inventory transaction authority")
	_expect(production_state_adapter != null and production_state_adapter.has_method("set_world_session_state") and production_state_adapter.has_method("actor_player_indices") and production_state_adapter.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the only v0.6 production player-state port and consumes the scene-owned session state")
	_expect(core_economic_adapter != null and core_economic_adapter.has_method("configure") and core_economic_adapter.has_method("play_card") and core_economic_adapter.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the shared v0.6 core-economic dispatch adapter")
	_expect(hand_interaction != null and hand_interaction.scene_file_path == "res://scenes/runtime/PlayerHandInteractionRuntimeService.tscn" and hand_interaction.has_method("plan_interaction") and hand_interaction.has_method("commit_interaction") and hand_interaction.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable PlayerHandInteractionRuntimeService scene and orchestration/cash/event-intent API")
	_expect(purchase_settlement != null and purchase_settlement.scene_file_path == "res://scenes/runtime/DistrictPurchaseSettlementRuntimeService.tscn" and purchase_settlement.has_method("plan_purchase") and purchase_settlement.has_method("commit_purchase") and purchase_settlement.has_method("validate_discard"), "GameRuntimeCoordinator owns the editable DistrictPurchaseSettlementRuntimeService scene")
	_expect(district_supply_snapshot != null and district_supply_snapshot.scene_file_path == "res://scenes/runtime/DistrictSupplySnapshotService.tscn" and district_supply_snapshot.has_method("compose") and district_supply_snapshot.has_method("validate_source") and district_supply_snapshot.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable DistrictSupplySnapshotService scene")
	_expect(district_supply_query != null and district_supply_query.scene_file_path == "res://scenes/runtime/presentation/DistrictSupplyViewerQueryPort.tscn" and district_supply_query.has_method("snapshot_for_viewer") and district_supply_query.has_method("debug_snapshot"), "GameRuntimeCoordinator owns one scene-owned viewer-safe DistrictSupplyViewerQueryPort")
	var district_query_debug: Dictionary = district_supply_query.call("debug_snapshot") if district_supply_query != null else {}
	_expect(not bool(district_query_debug.get("references_main", true)) and not bool(district_query_debug.get("mutates_gameplay", true)) and not bool(district_query_debug.get("opens_market_quote", true)) and not bool(district_query_debug.get("reads_future_supply_bag", true)), "district supply query declares a read-only non-Main presentation boundary before session wiring")
	_expect(district_supply_runtime_query != null and district_supply_runtime_query.scene_file_path == "res://scenes/runtime/DistrictSupplyRuntimeQueryPort.tscn" and district_supply_runtime_query.has_method("public_card_ids_for_district") and district_supply_runtime_query.has_method("bind_ai_private_capabilities"), "GameRuntimeCoordinator owns one non-presentation DistrictSupplyRuntimeQueryPort with actor-scoped AI-private capability boundaries")
	var district_runtime_query_debug: Dictionary = district_supply_runtime_query.call("debug_snapshot") if district_supply_runtime_query != null else {}
	_expect(not bool(district_runtime_query_debug.get("references_main", true)) and not bool(district_runtime_query_debug.get("mutates_gameplay", true)) and not bool(district_runtime_query_debug.get("reads_future_supply_bag", true)), "runtime district query is a read-only Main-free boundary")
	_expect(card_target_choice_response_sink != null and card_target_choice_response_sink.scene_file_path == "res://scenes/runtime/CardTargetChoiceResponseSink.tscn" and card_target_choice_response_sink.has_method("consume_authorized_response"), "GameRuntimeCoordinator owns one scene-owned card target-choice response sink")
	var target_response_debug: Dictionary = card_target_choice_response_sink.call("debug_snapshot") if card_target_choice_response_sink != null else {}
	_expect(not bool(target_response_debug.get("references_main", true)) and not bool(target_response_debug.get("owns_target_choice", true)) and not bool(target_response_debug.get("owns_card_queue", true)) and not bool(target_response_debug.get("owns_monster_roster", true)) and not bool(target_response_debug.get("owns_player_state", true)), "target-choice response sink delegates to the existing owners without Main or duplicate state")
	_expect(monster_wager_response_sink != null and monster_wager_response_sink.scene_file_path == "res://scenes/runtime/MonsterWagerResponseSink.tscn" and monster_wager_response_sink.has_method("consume_authorized_response"), "GameRuntimeCoordinator owns one scene-owned monster-wager response sink")
	var wager_response_debug: Dictionary = monster_wager_response_sink.call("debug_snapshot") if monster_wager_response_sink != null else {}
	_expect(not bool(wager_response_debug.get("references_main", true)) and not bool(wager_response_debug.get("owns_wager_state", true)) and not bool(wager_response_debug.get("owns_player_cash", true)) and not bool(wager_response_debug.get("owns_public_pool", true)) and not bool(wager_response_debug.get("owns_save_state", true)), "monster-wager response sink delegates to the existing owner without Main or duplicate state")
	for retired_diagnostic in ["_development_route_profiles", "_card_strength_budget_report", "_development_route_balance_audit", "_development_route_pressure_audit", "_direct_interaction_balance_report", "_role_balance_audit", "_monster_ecology_balance_report", "_product_ecosystem_report", "_card_supply_product_filter_audit", "_card_one_glance_audit_report", "_runtime_balance_snapshot"]:
		_expect(not main_source.contains("func %s(" % retired_diagnostic), "Sprint 62 deletes legacy main.gd diagnostic owner %s" % retired_diagnostic)
	for retired_economy_formatter in ["_economy_city_public_clue_line", "_city_product_market_price_summary", "_city_demand_price_summary", "_city_income_detail_lines", "_district_transport_speed", "_first_run_teaching_supply_gate", "_join_first_card_facts", "_product_list_with_prices", "_product_trend_text", "_district_connection_summary"]:
		_expect(not main_source.contains("func %s(" % retired_economy_formatter) and not main_source.contains("%s(" % retired_economy_formatter), "unused Main economy formatter stays physically absent: %s" % retired_economy_formatter)
	var district_action_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_action_port.gd")
	_expect(
		district_supply_action != null
		and district_supply_action.scene_file_path == "res://scenes/runtime/DistrictSupplyActionPort.tscn"
		and not district_action_source.contains("plan_district_purchase_settlement")
		and not district_action_source.contains("commit_district_purchase_with_region_supply")
		and district_action_source.contains("region_supply_listing")
		and not district_action_source.contains("player[\"cash\"] =")
		and not main_source.contains("func _buy_card_for_player_from_district(")
		and not main_source.contains("func _open_district_supply_from_map(")
		and not main_source.contains("func _assign_district_card_choices(")
		and not main_source.contains("func _normalize_card_supply_state(")
		and not main_source.contains("func _ensure_fixed_monster_card_supply(")
		and not main_source.contains("func _inject_first_table_followup_card_supply(")
		and not main_source.contains("district[\"card_choices\"]")
		and not main_source.contains("district[\"card_sources\"]"),
		"DistrictSupplyActionPort coordinates the scene-owned purchase lifecycle and Main no longer owns rack actions"
	)
	for retired_district_query in [
		"_district_region_id",
		"_district_supply_listing",
		"_district_supply_card_ids",
		"_district_supply_rack_revision",
		"_selected_district_card_choices",
		"_sync_selected_district_card",
		"_cycle_selected_district_card",
		"_district_has_card",
		"_card_market_preview",
		"_district_market_availability",
		"_district_market_currently_purchasable",
		"_district_market_availability_kind",
		"_district_market_availability_text",
		"_district_purchase_inventory_snapshot",
		"_district_purchase_inventory_plan",
		"_player_can_receive_card",
		"_discardable_hand_slots_for_purchase",
		"_player_can_receive_card_with_discard",
		"_purchase_requires_discard",
		"_pending_discard_purchase_for_player",
	]:
		_expect(
			not main_source.contains("func %s" % retired_district_query),
			"DistrictSupplyRuntimeQueryPort keeps Main query helper retired: %s" % retired_district_query
		)
	var effect_router_source := FileAccess.get_file_as_string("res://scripts/runtime/card_effect_runtime_router.gd")
	_expect(not main_source.contains("func _apply_player_hand_disrupt(") and not main_source.contains("func _apply_player_hand_steal(") and not main_source.contains("func _resolve_player_hand_interaction(") and effect_router_source.contains("func _resolve_player_interaction("), "typed effect routing deletes the three legacy Main interaction entry points")
	var interaction_service_source := FileAccess.get_file_as_string("res://scripts/runtime/player_hand_interaction_runtime_service.gd")
	_expect(effect_router_source.contains("_hand_interaction_service.plan_interaction") and effect_router_source.contains("_hand_interaction_service.commit_interaction") and interaction_service_source.contains("_inventory_service.call(\"commit_remove\"") and interaction_service_source.contains("_inventory_service.call(\"commit_lock\"") and interaction_service_source.contains("_inventory_service.call(\"commit_transfer\""), "typed effect router delegates all player-interaction slot mutation to CardInventoryRuntimeService")
	var queue_submit_source := FileAccess.get_file_as_string("res://scripts/runtime/card_play_submission_runtime_controller.gd")
	var transition_sink_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_transition_sink.gd")
	var execution_port_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_world_bridge.gd")
	_expect(not main_source.contains("var card_resolution_queue := []") and not main_source.contains("var next_card_resolution_queue := []") and not main_source.contains("var active_card_resolution := {}") and not main_source.contains("var card_resolution_sequence := 0") and not main_source.contains("func _queue_skill_resolution(") and queue_submit_source.contains("plan_card_resolution_queue_submission") and queue_submit_source.contains("commit_card_inventory_queue_commit") and queue_submit_source.contains("commit_card_resolution_queue_submission") and transition_sink_source.contains("func _lock_batch(") and transition_sink_source.contains("func _start_next(") and execution_port_source.contains("func lock_batch_transition(") and execution_port_source.contains("func start_next_transition("), "typed submission owns queue admission while TransitionSink routes lifecycle to the single queue service")
	var execution_complete_source := transition_sink_source
	var execution_effect_adapter_source := effect_router_source
	var execution_service_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_runtime_service.gd")
	var family_service_source := FileAccess.get_file_as_string("res://scripts/runtime/card_economy_product_route_effect_runtime_service.gd")
	var formula_service_source := FileAccess.get_file_as_string("res://scripts/runtime/card_economy_product_route_formula_runtime_service.gd")
	_expect(ResourceLoader.exists(CARD_RESOLUTION_EXECUTION_BENCH) and ResourceLoader.exists(CARD_RESOLUTION_EXECUTION_SERVICE) and ResourceLoader.exists(CARD_RESOLUTION_EXECUTION_WORLD_BRIDGE) and ResourceLoader.exists(CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE) and FileAccess.file_exists(CARD_RESOLUTION_EXECUTION_CONTRACT), "Sprint 40 composes the durable execution/effect/formula services, stateless world bridges, 80-case gate, and contracts")
	_expect(not main_source.contains("func _resolve_queued_skill("), "Sprint 41 keeps the Sprint 40 legacy execution shell absent")
	var ai_algorithm_regex := RegEx.new()
	ai_algorithm_regex.compile("(?m)^func\\s+(_ai_(?!runtime_)[A-Za-z0-9_]*|_auto_ai_[A-Za-z0-9_]*|_update_ai_decisions|_record_ai_decision|_finalize_ai_[A-Za-z0-9_]*)\\(")
	var ai_controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(ai_algorithm_regex.search(main_source) == null and ai_controller_source.contains("func _ai_card_play_candidates(") and ai_controller_source.contains("func _ai_card_buy_candidates(") and not main_source.contains("const AI_PERSONALITY_CATALOG") and not main_source.contains("const AI_CARD_DECISION_INTERVAL_SECONDS"), "Sprint 41 removes AI candidates, scores, policy constants, and decision loops from main.gd")
	var card_presentation_source := FileAccess.get_file_as_string("res://scripts/runtime/card_presentation_runtime_service.gd")
	var table_viewmodel_source := FileAccess.get_file_as_string("res://scripts/runtime/game_table_viewmodel_runtime_service.gd")
	var retired_presentation_functions := ["_card_theme_color", "_card_category_icon", "_card_use_case_text_for_skill", "_card_rules_text", "_card_rule_facts", "_card_detail_tooltip", "_runtime_hand_card_snapshots", "_runtime_card_track_snapshot_source", "_runtime_right_inspector_snapshot_source", "_runtime_card_resolution_track_snapshot_source", "_card_resolution_track_badge_texts", "_card_resolution_track_badge_color", "_card_resolution_overlay_badge_texts", "_card_resolution_contract_badge_text"]
	var presentation_cutover_checked := not main_source.contains("TableSnapshotScript") and card_presentation_source.contains("func compose_card(") and card_presentation_source.contains("func compose_hand_card(") and table_viewmodel_source.contains("func compose_table(") and table_viewmodel_source.contains("func _compose_right_inspector(") and table_viewmodel_source.contains("func _compose_track(")
	for function_name in retired_presentation_functions:
		presentation_cutover_checked = presentation_cutover_checked and not main_source.contains("func %s(" % function_name)
	_expect(presentation_cutover_checked, "Sprint 42 removes parallel card presentation, hand/track/Inspector, and TableSnapshot owners from main.gd")
	var retired_eligibility_functions := ["_hand_card_play_state", "_can_play_skill_now", "_skill_play_requirement_profile", "_skill_play_requirement_status", "_skill_play_requirement_text", "_skill_play_requirement_chip_text", "_skill_play_region_share_required", "_skill_play_region_scope", "_skill_play_requirement_district", "_skill_play_cash_cost", "_skill_targets_monster", "_skill_targets_player", "_skill_requires_target_monster", "_skill_requires_target_player", "_is_direct_monster_skill_kind", "_is_counter_skill", "_skill_is_counterable_player_interaction", "_can_convert_monster_card_to_counter", "_card_play_requirement_audit"]
	var eligibility_cutover_checked := card_play_eligibility != null and card_play_world_bridge != null and main_source.contains("func _card_play_eligibility_snapshot(") and main_source.contains("func _authorize_card_play(")
	for function_name in retired_eligibility_functions:
		eligibility_cutover_checked = eligibility_cutover_checked and not main_source.contains("func %s(" % function_name)
	_expect(eligibility_cutover_checked, "Sprint 43 removes parallel card eligibility, requirement, target-trait, and counter-trait ownership from main.gd")
	_expect(execution_complete_source.contains("func _complete_active(") and execution_complete_source.contains("_execution.plan_execution") and execution_complete_source.contains("_execution.finalize_execution") and not main_source.contains("func _complete_active_card_resolution(") and execution_effect_adapter_source.contains("_resolve_targeted_skill") and execution_effect_adapter_source.contains("_resolve_player_interaction") and execution_service_source.contains("INTENT_RELEASE_ACTIVE") and execution_service_source.contains("INTENT_DISPATCH_EFFECT") and not main_source.contains("func _apply_card_resolution_effect_request("), "typed TransitionSink routes lifecycle through Execution Service and scene-owned effect router")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var v04_catalog_scene_source := FileAccess.get_file_as_string(CARD_RUNTIME_CATALOG_SERVICE)
	var commodity_inventory_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_card_inventory_runtime_controller.gd")
	var core_economic_adapter_source := FileAccess.get_file_as_string("res://scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd")
	var namespace_cutover_checked := execution_effect_adapter_source.contains("_economy_service.plan_effect") and execution_effect_adapter_source.contains("_economy_service.finalize_effect") and family_service_source.contains("HANDLER_FAMILIES")
	namespace_cutover_checked = namespace_cutover_checked and formula_service_source.contains("FORMULA_IDS") and not execution_service_source.contains("CoreEconomicCardRuntimeAdapterV06") and not execution_service_source.contains("CommodityCardInventoryRuntimeController")
	namespace_cutover_checked = namespace_cutover_checked and v04_catalog_scene_source.contains("card_runtime_catalog_v04.tres") and not v04_catalog_scene_source.contains("card_runtime_catalog_v06")
	namespace_cutover_checked = namespace_cutover_checked and coordinator_source.contains("func play_v06_runtime_card(") and coordinator_source.contains('== "core_economic_card_runtime"') and coordinator_source.contains('inventory.call("play_core_card"')
	namespace_cutover_checked = namespace_cutover_checked and commodity_inventory_source.contains("func play_core_card(") and core_economic_adapter_source.contains("func play_card(") and main_source.contains("func _play_v06_runtime_card_for_player(")
	_expect(namespace_cutover_checked, "legacy v0.4 effect/formula services stay isolated while v0.6 core cards use the single CardFlow transaction facade")
	_expect(not main_source.contains("func _lowest_level_city_product_index(") and not main_source.contains("func _product_futures_balance_") and not main_source.contains("PRODUCT_FUTURES_PAYOUT_UNIT") and not execution_service_source.contains("CardEconomyProductRouteFormulaRuntimeService"), "retired formula ownership stays absent from main and the Execution Service remains formula-agnostic")
	_expect(codex_navigation != null and codex_navigation.scene_file_path == "res://scenes/runtime/CodexNavigationRuntimeController.tscn" and codex_navigation.has_method("navigation_snapshot") and codex_navigation.has_method("to_legacy_save_snapshot") and codex_navigation.has_method("apply_legacy_save_snapshot"), "GameRuntimeCoordinator owns the editable CodexNavigationRuntimeController scene")
	_expect(codex_public_snapshot != null and codex_public_snapshot.scene_file_path == "res://scenes/runtime/CodexPublicSnapshotService.tscn" and codex_public_snapshot.has_method("compose_role") and codex_public_snapshot.has_method("compose_region"), "GameRuntimeCoordinator owns the editable CodexPublicSnapshotService scene")
	_expect(monster_codex_public_snapshot != null and monster_codex_public_snapshot.scene_file_path == "res://scenes/runtime/MonsterCodexPublicSnapshotService.tscn" and monster_codex_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable MonsterCodexPublicSnapshotService scene")
	_expect(monster_codex_public_source != null and monster_codex_public_source.scene_file_path == "res://scenes/runtime/MonsterCodexPublicSourceService.tscn" and monster_codex_public_source.has_method("compose_browser_source") and monster_codex_public_source.has_method("compose_detail_source") and monster_codex_public_source.has_method("debug_snapshot"), "GameRuntimeCoordinator uniquely owns the scene-backed public-only Monster Codex source service")
	_expect(coordinator != null and coordinator.has_method("monster_codex_public_browser_snapshot") and coordinator.has_method("monster_codex_public_detail_snapshot") and not coordinator.has_method("compose_monster_codex_snapshot"), "GameRuntimeCoordinator exposes Monster Codex browser/detail public snapshot boundaries without a generic source proxy")
	_expect(product_codex_public_snapshot != null and product_codex_public_snapshot.scene_file_path == "res://scenes/runtime/ProductCodexPublicSnapshotService.tscn" and product_codex_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable ProductCodexPublicSnapshotService scene")
	_expect(product_codex_public_source != null and product_codex_public_source.scene_file_path == "res://scenes/runtime/ProductCodexPublicSourceService.tscn" and product_codex_public_source.has_method("compose_browser_snapshot") and product_codex_public_source.has_method("compose_snapshot") and product_codex_public_source.has_method("debug_snapshot"), "GameRuntimeCoordinator uniquely owns the scene-backed public-only Product Codex source service")
	_expect(coordinator != null and coordinator.has_method("product_codex_public_browser_snapshot") and coordinator.has_method("product_codex_public_detail_snapshot") and not coordinator.has_method("compose_product_codex_snapshot"), "GameRuntimeCoordinator exposes Product Codex browser/detail public snapshot boundaries without a generic source proxy")
	_expect(card_codex_public_snapshot != null and card_codex_public_snapshot.scene_file_path == "res://scenes/runtime/CardCodexPublicSnapshotService.tscn" and card_codex_public_snapshot.has_method("compose_browser") and card_codex_public_snapshot.has_method("compose_detail"), "GameRuntimeCoordinator owns the editable CardCodexPublicSnapshotService scene")
	_expect(card_codex_public_source != null and card_codex_public_source.scene_file_path == CARD_CODEX_PUBLIC_SOURCE_SERVICE and card_codex_public_source.has_method("compose_browser") and card_codex_public_source.has_method("compose_detail") and card_codex_public_source.has_method("debug_snapshot"), "GameRuntimeCoordinator uniquely owns the scene-backed public-only Card Codex source service")
	_expect(coordinator != null and coordinator.has_method("card_codex_public_browser_snapshot") and coordinator.has_method("card_codex_public_detail_snapshot"), "GameRuntimeCoordinator exposes only the browser/detail Card Codex public snapshot boundary")
	_expect(region_codex_public_source != null and region_codex_public_source.scene_file_path == REGION_CODEX_PUBLIC_SOURCE_SERVICE and region_codex_public_source.has_method("compose_source") and region_codex_public_source.has_method("compose_region") and region_codex_public_source.has_method("debug_snapshot"), "GameRuntimeCoordinator uniquely owns the scene-backed public-only Region Codex source service")
	_expect(coordinator != null and coordinator.has_method("region_codex_public_snapshot") and not coordinator.has_method("compose_codex_region_snapshot"), "GameRuntimeCoordinator exposes one final Region Codex snapshot boundary without a generic source proxy")
	_expect(economy_dashboard_public_snapshot != null and economy_dashboard_public_snapshot.scene_file_path == "res://scenes/runtime/EconomyDashboardPublicSnapshotService.tscn" and economy_dashboard_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable EconomyDashboardPublicSnapshotService scene")
	_expect(standings_public_snapshot != null and standings_public_snapshot.scene_file_path == "res://scenes/runtime/StandingsPublicSnapshotService.tscn" and standings_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable StandingsPublicSnapshotService scene")
	_expect(final_settlement_public_snapshot != null and final_settlement_public_snapshot.scene_file_path == "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn" and final_settlement_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable FinalSettlementPublicSnapshotService scene")
	_expect(final_settlement_composition != null and final_settlement_composition.scene_file_path == "res://scenes/runtime/FinalSettlementRuntimeComposition.tscn" and final_settlement_composition.has_method("present") and final_settlement_composition.has_method("compose_public_snapshot") and final_settlement_composition.get_node_or_null("FinalSettlementPublicSourceAdapter") != null and final_settlement_composition.get_node_or_null("FinalSettlementBoardPanel") != null, "main owns one editable FinalSettlementRuntimeComposition with the existing source adapter and board")
	_expect(developer_balance_host != null and developer_balance_host.scene_file_path == "res://scenes/runtime/presentation/DeveloperBalanceApplicationHost.tscn", "main owns one scene-backed developer balance application host")
	_expect(developer_balance_host != null and developer_balance_host.panel_parent_path == NodePath("../../RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer") and developer_balance_host.presentation_target_path == NodePath("../RuntimeControllerHost/GameRuntimeCoordinator/DeveloperBalancePresentationTarget"), "developer balance host uses explicit overlay and existing typed-target paths")
	_expect(main.find_children("DeveloperBalanceApplicationHost", "DeveloperBalanceApplicationHost", true, false).size() == 1, "production composition contains exactly one developer balance application host")
	_expect(main.find_children("DeveloperBalancePresentationTarget", "DeveloperBalancePresentationTarget", true, false).size() == 1, "production composition retains exactly one developer balance presentation target")
	for retired_final_settlement_symbol in ["_open_final_settlement_menu", "_populate_final_settlement_summary_cards", "_add_final_settlement_board_panel", "_final_settlement_public_facts", "_final_settlement_public_snapshot", "_on_final_settlement_action_requested", "_final_settlement_public_summary_text"]:
		_expect(not main_source.contains("func %s(" % retired_final_settlement_symbol), "Final Settlement composition cutover deletes main.%s" % retired_final_settlement_symbol)
	_expect(intel_dossier_public_snapshot != null and intel_dossier_public_snapshot.scene_file_path == "res://scenes/runtime/IntelDossierPublicSnapshotService.tscn" and intel_dossier_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable IntelDossierPublicSnapshotService scene")
	var audio_host := main.get_node_or_null("RuntimeServices/TableAudioHost")
	for player_name in ["NightPatrolTableBgm", "NightPatrolSfx_card", "NightPatrolSfx_impact", "NightPatrolSfx_storm"]:
		_expect(audio_host != null and audio_host.get_node_or_null(player_name) is AudioStreamPlayer, "TableAudioHost owns %s" % player_name)


func _check_runtime_snapshot(main: Control, phase: String) -> void:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null and coordinator.has_method("debug_snapshot"), "GameRuntimeCoordinator exposes the production composition snapshot")
	if coordinator == null or not coordinator.has_method("debug_snapshot"):
		return
	var coordinator_snapshot: Dictionary = coordinator.call("debug_snapshot")
	_expect(_is_pure_data(coordinator_snapshot), "%s Coordinator snapshot contains pure data only" % phase)
	_expect(bool(coordinator_snapshot.get("coordinator_composition_ready", false)), "%s static production composition is ready" % phase)
	_expect(str(coordinator_snapshot.get("ruleset_id", "")) == "v0.4", "%s retains the v0.4 global bridge namespace" % phase)
	var production_binding: Dictionary = coordinator_snapshot.get("v06_production_player_bindings", {}) if coordinator_snapshot.get("v06_production_player_bindings", {}) is Dictionary else {}
	var actor_count := int(production_binding.get("actor_count", 0))
	_expect(bool(coordinator_snapshot.get("v06_production_player_bindings_ready", false)) == (actor_count > 0 and bool(production_binding.get("state_adapter_ready", false)) and bool(production_binding.get("inventory_ready", false)) and bool(production_binding.get("core_economic_ready", false)) and bool(production_binding.get("monster_card_adapter_ready", false))), "%s strict readiness reflects the post-seat v0.6 binding result" % phase)
	var scheduler_snapshot: Dictionary = coordinator_snapshot.get("forced_decision_scheduler", {}) if coordinator_snapshot.get("forced_decision_scheduler", {}) is Dictionary else {}
	var session_snapshot: Dictionary = coordinator_snapshot.get("game_session", {}) if coordinator_snapshot.get("game_session", {}) is Dictionary else {}
	var purchase_snapshot: Dictionary = coordinator_snapshot.get("district_purchase", {}) if coordinator_snapshot.get("district_purchase", {}) is Dictionary else {}
	var card_inventory_snapshot: Dictionary = coordinator_snapshot.get("card_inventory", {}) if coordinator_snapshot.get("card_inventory", {}) is Dictionary else {}
	var card_resolution_queue_snapshot: Dictionary = coordinator_snapshot.get("card_resolution_queue", {}) if coordinator_snapshot.get("card_resolution_queue", {}) is Dictionary else {}
	var action_result_presentation_snapshot: Dictionary = coordinator_snapshot.get("action_result_presentation", {}) if coordinator_snapshot.get("action_result_presentation", {}) is Dictionary else {}
	var effect_formula_snapshot: Dictionary = coordinator_snapshot.get("card_economy_product_route_formula", {}) if coordinator_snapshot.get("card_economy_product_route_formula", {}) is Dictionary else {}
	var purchase_settlement_snapshot: Dictionary = coordinator_snapshot.get("district_purchase_settlement", {}) if coordinator_snapshot.get("district_purchase_settlement", {}) is Dictionary else {}
	var district_supply_snapshot: Dictionary = coordinator_snapshot.get("district_supply_snapshot", {}) if coordinator_snapshot.get("district_supply_snapshot", {}) is Dictionary else {}
	var commodity_flow_snapshot: Dictionary = coordinator_snapshot.get("commodity_flow_runtime", {}) if coordinator_snapshot.get("commodity_flow_runtime", {}) is Dictionary else {}
	var player_mana_snapshot: Dictionary = coordinator_snapshot.get("player_mana_runtime", {}) if coordinator_snapshot.get("player_mana_runtime", {}) is Dictionary else {}
	var commodity_inventory_snapshot: Dictionary = coordinator_snapshot.get("commodity_card_inventory_runtime", {}) if coordinator_snapshot.get("commodity_card_inventory_runtime", {}) is Dictionary else {}
	var production_state_snapshot: Dictionary = coordinator_snapshot.get("card_player_state_production_adapter_v06", {}) if coordinator_snapshot.get("card_player_state_production_adapter_v06", {}) is Dictionary else {}
	var core_economic_snapshot: Dictionary = coordinator_snapshot.get("core_economic_card_runtime_adapter_v06", {}) if coordinator_snapshot.get("core_economic_card_runtime_adapter_v06", {}) is Dictionary else {}
	var region_snapshot: Dictionary = coordinator_snapshot.get("region_infrastructure_runtime", {}) if coordinator_snapshot.get("region_infrastructure_runtime", {}) is Dictionary else {}
	var victory_snapshot: Dictionary = coordinator_snapshot.get("victory_control_runtime", {}) if coordinator_snapshot.get("victory_control_runtime", {}) is Dictionary else {}
	var card_presentation_snapshot: Dictionary = coordinator_snapshot.get("card_presentation", {}) if coordinator_snapshot.get("card_presentation", {}) is Dictionary else {}
	var table_viewmodel_snapshot: Dictionary = coordinator_snapshot.get("game_table_viewmodel", {}) if coordinator_snapshot.get("game_table_viewmodel", {}) is Dictionary else {}
	_expect(scheduler_snapshot.get("priority_order", []) == ["monster_wager", "counter_response", "other_choice", "public_bid"], "%s preserves RulesetRuntimeBridge priorities and appends public_bid as the lowest forced-decision priority" % phase)
	_expect(bool(session_snapshot.get("session_ready", false)) and bool(session_snapshot.get("session_authoritative", false)), "%s configures scene-owned session/save authority" % phase)
	_expect(bool(purchase_snapshot.get("controller_ready", false)) and bool(purchase_snapshot.get("controller_authoritative", false)) and bool(purchase_snapshot.get("session_authority_only", false)) and not bool(purchase_snapshot.get("pricing_authority", true)) and not bool(purchase_snapshot.get("access_authority", true)) and bool(purchase_snapshot.get("legacy_monster_gate_retired", false)), "%s configures DistrictPurchase as session-only while CardMarketPricing owns eligibility and quotes" % phase)
	_expect(bool(card_inventory_snapshot.get("service_ready", false)) and bool(card_inventory_snapshot.get("service_authoritative", false)) and int(card_inventory_snapshot.get("ordinary_hand_limit", 0)) == 5 and int(card_inventory_snapshot.get("maximum_card_rank", 0)) == 4 and not bool(card_inventory_snapshot.get("purchase_cash_authority", true)) and not bool(card_inventory_snapshot.get("ledger_authority", true)) and not bool(card_inventory_snapshot.get("legacy_inventory_fallback_used", true)), "%s configures CardInventoryRuntimeService as the v0.4 slot-mutation authority without moving cash or ledger ownership" % phase)
	_expect(bool(card_resolution_queue_snapshot.get("service_ready", false)) and bool(card_resolution_queue_snapshot.get("service_authoritative", false)) and not bool(card_resolution_queue_snapshot.get("timing_authority", true)) and not bool(card_resolution_queue_snapshot.get("card_effect_authority", true)) and not bool(card_resolution_queue_snapshot.get("inventory_authority", true)), "%s keeps the legacy queue in its narrow authority boundary" % phase)
	_expect(bool(action_result_presentation_snapshot.get("service_ready", false)) and not bool(action_result_presentation_snapshot.get("service_authoritative", true)) and bool(action_result_presentation_snapshot.get("owns_action_result_presentation", false)) and not bool(action_result_presentation_snapshot.get("owns_rules", true)) and not bool(action_result_presentation_snapshot.get("owns_save_state", true)) and not bool(action_result_presentation_snapshot.get("reads_world_bridge", true)) and not bool(action_result_presentation_snapshot.get("mutates_game_state", true)), "%s configures ActionResult v1 as public copy only, never action authority" % phase)
	_expect(bool(effect_formula_snapshot.get("service_ready", false)) and bool(effect_formula_snapshot.get("pure_formula_authority", false)) and not bool(effect_formula_snapshot.get("effect_dispatch_authority", true)) and not bool(effect_formula_snapshot.get("world_mutation_authority", true)) and not bool(effect_formula_snapshot.get("execution_lifecycle_authority", true)), "%s configures the pure Formula Service without expanding execution or world ownership" % phase)
	_expect(bool(purchase_settlement_snapshot.get("service_ready", false)) and bool(purchase_settlement_snapshot.get("service_authoritative", false)) and not bool(purchase_settlement_snapshot.get("window_authority", true)) and not bool(purchase_settlement_snapshot.get("presentation_authority", true)) and not bool(purchase_settlement_snapshot.get("legacy_settlement_fallback_used", true)), "%s configures the scene-owned atomic District Purchase Settlement service without moving window or presentation authority" % phase)
	_expect(bool(district_supply_snapshot.get("service_ready", false)) and bool(district_supply_snapshot.get("service_authoritative", false)) and not bool(district_supply_snapshot.get("calculates_purchase_eligibility", true)) and not bool(district_supply_snapshot.get("calculates_card_price", true)) and not bool(district_supply_snapshot.get("mutates_inventory", true)), "%s configures the scene-owned District Supply presentation formatter without moving purchase rules" % phase)
	_expect(bool(commodity_flow_snapshot.get("controller_ready", false)) and bool(commodity_flow_snapshot.get("controller_authoritative", false)) and bool(commodity_flow_snapshot.get("owns_fixed_point_flow", false)) and bool(commodity_flow_snapshot.get("owns_sale_receipt_ledger", false)) and not bool(commodity_flow_snapshot.get("owns_cash_state", true)), "%s configures CommodityFlow as the single continuous economy and sale-receipt owner" % phase)
	_expect(bool(player_mana_snapshot.get("controller_ready", false)) and bool(player_mana_snapshot.get("controller_authoritative", false)) and bool(player_mana_snapshot.get("asset_balance_authority", false)) and not bool(player_mana_snapshot.get("commodity_flow_authority", true)), "%s configures PlayerMana as the single six-color asset owner" % phase)
	_expect(str(commodity_inventory_snapshot.get("ruleset_id", "")) == "v0.6" and str(commodity_inventory_snapshot.get("catalog_path", "")) == "res://resources/cards/runtime/card_runtime_catalog_v06.tres" and not bool(commodity_inventory_snapshot.get("stores_player_inventory", true)), "%s configures the v0.6 catalog behind one transaction authority without replacing the v0.4 global catalog" % phase)
	_expect(not bool(production_state_snapshot.get("stores_inventory", true)) and not bool(production_state_snapshot.get("stores_cash", true)) and not bool(production_state_snapshot.get("stores_assets", true)), "%s keeps the production state adapter non-owning" % phase)
	_expect(bool(core_economic_snapshot.get("uses_shared_card_source_transaction_service", false)) and not bool(core_economic_snapshot.get("owns_hand_state", true)) and not bool(core_economic_snapshot.get("owns_cash_state", true)) and not bool(core_economic_snapshot.get("owns_asset_state", true)), "%s keeps the core-economic adapter on the shared CardFlow transaction" % phase)
	_expect(bool(region_snapshot.get("controller_ready", false)) and str(region_snapshot.get("ruleset_id", "")) == "v0.6" and bool(region_snapshot.get("facility_rollback_atomic_ready", false)) and not bool(region_snapshot.get("has_heat_state", true)), "%s configures RegionInfrastructure as the v0.6 facility/shared-life owner" % phase)
	_expect(bool(victory_snapshot.get("controller_ready", false)) and str(victory_snapshot.get("ruleset_id", "")) == "v0.6" and bool(victory_snapshot.get("dynamic_denominator_enabled", false)) and not bool(victory_snapshot.get("fixed_depth_table_present", true)), "%s configures the unique v0.6 Victory owner" % phase)
	_expect(not coordinator_snapshot.has("city_development_runtime") and not coordinator_snapshot.has("economy_cashflow") and not coordinator_snapshot.has("industry_capacity_runtime"), "%s does not revive retired city-project, parallel cashflow, or industry-capacity owners" % phase)
	_expect(bool(card_presentation_snapshot.get("service_ready", false)) and bool(card_presentation_snapshot.get("service_authoritative", false)) and bool(card_presentation_snapshot.get("owns_card_use_case", false)) and bool(card_presentation_snapshot.get("owns_hand_card_viewmodel", false)) and not bool(card_presentation_snapshot.get("calculates_card_price", true)) and not bool(card_presentation_snapshot.get("calculates_play_legality", true)) and not bool(card_presentation_snapshot.get("mutates_game_state", true)), "%s configures scene-owned card presentation without moving price, legality, or mutation rules" % phase)
	_expect(bool(table_viewmodel_snapshot.get("service_ready", false)) and bool(table_viewmodel_snapshot.get("service_authoritative", false)) and bool(table_viewmodel_snapshot.get("owns_table_snapshot_normalization", false)) and bool(table_viewmodel_snapshot.get("owns_right_inspector_assembly", false)) and bool(table_viewmodel_snapshot.get("owns_public_track_viewmodels", false)) and bool(table_viewmodel_snapshot.get("owns_resolution_overlay_badges", false)) and not bool(table_viewmodel_snapshot.get("calculates_play_legality", true)) and not bool(table_viewmodel_snapshot.get("mutates_game_state", true)), "%s configures scene-owned TableSnapshot, public track, resolution-overlay badge, and RightInspector assembly" % phase)
	_expect(bool(card_presentation_snapshot.get("owns_resolution_presentation", false)), "%s configures scene-owned card-resolution cinematic presentation" % phase)
	var save_snapshot: Dictionary = session_snapshot.get("save_operation", {}) if session_snapshot.get("save_operation", {}) is Dictionary else {}
	_expect(int(save_snapshot.get("save_version", 0)) == 3 and str(save_snapshot.get("default_save_path", "")).is_empty() and bool(save_snapshot.get("explicit_path_required", false)), "%s preserves the v3 fail-closed save version and explicit-path contract" % phase)


func _check_runtime_signal_bindings(main: Control) -> void:
	var screen := main.get_node_or_null("RuntimeGameScreen") as Control
	if screen == null:
		return
	var bindings := {
		"action_requested": "_on_runtime_game_screen_action_requested",
		"end_turn_requested": "_on_runtime_game_screen_end_turn_requested",
		"card_drop_requested": "_on_runtime_game_screen_card_drop_requested",
	}
	for signal_name_variant in bindings.keys():
		var signal_name := StringName(signal_name_variant)
		var expected := Callable(main, StringName(bindings[signal_name_variant]))
		var count := 0
		for connection_variant in screen.get_signal_connection_list(signal_name):
			var connection: Dictionary = connection_variant if connection_variant is Dictionary else {}
			if connection.get("callable", Callable()) == expected:
				count += 1
		_expect(count == 1, "%s is connected to main exactly once" % signal_name)
	var legacy_card_selection := Callable(main, &"_on_runtime_game_screen_card_selected")
	var legacy_count := 0
	for connection_variant in screen.get_signal_connection_list(&"card_selected"):
		var connection: Dictionary = connection_variant if connection_variant is Dictionary else {}
		if connection.get("callable", Callable()) == legacy_card_selection:
			legacy_count += 1
	_expect(legacy_count == 0, "card_selected no longer routes hand focus through Main")
	var selection_port := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/TableSelectionIntentPort") as TableSelectionIntentPort
	_expect(selection_port != null, "scene composition exposes the typed table-selection port")
	if selection_port != null:
		var request_count := 0
		for connection_variant in screen.get_signal_connection_list(&"table_selection_intent_requested"):
			var connection: Dictionary = connection_variant if connection_variant is Dictionary else {}
			if connection.get("callable", Callable()) == Callable(selection_port, &"submit_intent"):
				request_count += 1
		var receipt_count := 0
		for connection_variant in selection_port.get_signal_connection_list(&"receipt_ready"):
			var connection: Dictionary = connection_variant if connection_variant is Dictionary else {}
			if connection.get("callable", Callable()) == Callable(screen, &"apply_table_selection_receipt"):
				receipt_count += 1
		_expect(request_count == 1 and receipt_count == 1, "typed table-selection request and receipt are each connected exactly once")


func _check_runtime_controller_authority(main: Control) -> void:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionRuntimeController")
	if controller == null:
		return
	_expect(is_equal_approx(float(controller.get("total_window_seconds")), 30.0) and is_equal_approx(float(controller.get("planning_seconds")), 20.0) and is_equal_approx(float(controller.get("public_bid_seconds")), 5.0) and is_equal_approx(float(controller.get("lock_seconds")), 5.0) and is_equal_approx(float(controller.get("opening_total_window_seconds")), 45.0) and is_equal_approx(float(controller.get("opening_planning_seconds")), 35.0), "production main consumes the v0.6 standard and opening shared-window cadence")
	var expected_counter_seconds := 0.0 if DisplayServer.get_name().to_lower() == "headless" else 5.0
	_expect(is_equal_approx(float(controller.get("counter_seconds")), expected_counter_seconds), "RulesetRuntimeBridge preserves the response-window duration, with the established headless shortcut")
	main.set("card_resolution_simultaneous_timer", 12.0)
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 12.0), "main compatibility property writes into the scene-owned controller")
	controller.set("simultaneous_timer", 9.0)
	_expect(is_equal_approx(float(main.get("card_resolution_simultaneous_timer")), 9.0), "main compatibility property reads from the scene-owned controller authority")
	main.set("card_resolution_auction_timer", 4.0)
	main.set("card_resolution_auction_open", true)
	main.set("card_group_window_sequence", 12)
	var saved: Dictionary = controller.call("to_save_data")
	_expect(is_equal_approx(float(saved.get("card_resolution_simultaneous_timer", 0.0)), 9.0) and int(saved.get("card_group_window_sequence", 0)) == 12, "CardResolutionRuntimeController is the save source for its existing wire keys")
	var legacy_lock_state := saved.duplicate(true)
	legacy_lock_state["card_resolution_simultaneous_timer"] = 0.0
	legacy_lock_state["card_resolution_auction_timer"] = 4.0
	legacy_lock_state["card_resolution_auction_open"] = true
	controller.call("apply_save_data", legacy_lock_state)
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 9.0), "CardResolutionRuntimeController maps a legacy auction-only save into the five-second public-bid phase without a second timer owner")
	if controller.has_method("reset_state"):
		controller.call("reset_state")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var purchase := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseRuntimeController")
	_expect(coordinator != null and purchase != null, "district purchase controller is available for runtime authority checks")
	if coordinator != null and purchase != null:
		purchase.call("reset_state")
		var purchase_window: Dictionary = coordinator.call("open_district_purchase_window", 0, 2, {"supply_revision": "composition-a"})
		_expect(bool(purchase_window.get("active", false)) and int(purchase_window.get("district_index", -1)) == 2 and not purchase_window.has("remaining_seconds") and not purchase_window.has("locked_price_multiplier"), "district purchase controller owns only the active browsing session and no legacy timer or price authority")
		var legacy_purchase: Dictionary = coordinator.call("district_purchase_legacy_save_snapshot", 0)
		_expect(int(legacy_purchase.get("schema_version", 0)) == 2 and int(legacy_purchase.get("district_index", -1)) == 2 and (legacy_purchase.get("active_quote", {}) as Dictionary).is_empty(), "existing purchase-session wire captures a quote-less browsing session without live repricing")
		var purchase_source := FileAccess.get_file_as_string("res://scripts/runtime/district_purchase_runtime_controller.gd")
		var purchase_coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
		_expect(not purchase_source.contains("func tick_window(") and not purchase_coordinator_source.contains("func tick_district_purchase_windows("), "obsolete twelve-second purchase-window tick APIs are physically deleted with zero production reference")
		purchase.call("reset_state")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var monster_controller_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var monster_contract := FileAccess.get_file_as_string(MONSTER_RUNTIME_OWNERSHIP_CONTRACT)
	var monster_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController")
	var monster_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeWorldBridge")
	var monster_cutover_ready := ResourceLoader.exists(MONSTER_RUNTIME_CONTROLLER) and ResourceLoader.exists(MONSTER_RUNTIME_WORLD_BRIDGE) and ResourceLoader.exists(MONSTER_RUNTIME_CHARACTERIZATION_BENCH) and ResourceLoader.exists(MONSTER_RUNTIME_CHARACTERIZATION_SCRIPT) and not monster_contract.is_empty()
	monster_cutover_ready = monster_cutover_ready and monster_controller != null and monster_bridge != null
	if monster_controller != null:
		monster_cutover_ready = monster_cutover_ready and monster_controller.has_method("configure") and monster_controller.has_method("reset_state") and monster_controller.has_method("roster_snapshot") and monster_controller.has_method("to_save_data") and monster_controller.has_method("apply_save_data") and monster_controller.has_method("debug_snapshot")
		var monster_debug: Dictionary = monster_controller.call("debug_snapshot")
		monster_cutover_ready = monster_cutover_ready and bool(monster_debug.get("controller_authoritative", false)) and not bool(monster_debug.get("parallel_legacy_owner", true)) and _is_pure_data(monster_debug)
	for legacy_symbol in ["var auto_monsters := []", "var active_monster_wagers := []", "func _summon_monster_from_card(", "func _weighted_auto_monster_target(", "func _auto_monster_movement_tick(", "func _auto_monster_take_damage(", "func _open_monster_wager_for_pair("]:
		monster_cutover_ready = monster_cutover_ready and not main_source.contains(str(legacy_symbol))
	for controller_symbol in ["var auto_monsters: Array = []", "func _summon_monster_from_card(", "func _weighted_auto_monster_target(", "func _auto_monster_movement_tick(", "func _auto_monster_take_damage(", "func _open_monster_wager_for_pair("]:
		monster_cutover_ready = monster_cutover_ready and monster_controller_source.contains(str(controller_symbol))
	monster_cutover_ready = monster_cutover_ready and coordinator_source.contains("bool(monster_runtime_snapshot.get(\"controller_authoritative\", false))")
	_expect(monster_cutover_ready and main_source.sha256_text() != "46eb1f21e1d8182d78d16af4858eb3b90081da2c9644b50f81594469a667cc99", "Sprint 45 composes one authoritative MonsterRuntimeController and non-owning bridge while legacy main.gd monster state and algorithms stay deleted")
	var military_contract := FileAccess.get_file_as_string(MILITARY_RUNTIME_OWNERSHIP_CONTRACT)
	var military_controller_source := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	var military_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeController")
	var military_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeWorldBridge")
	var military_bench_ready := ResourceLoader.exists(MILITARY_RUNTIME_CHARACTERIZATION_BENCH) and ResourceLoader.exists(MILITARY_RUNTIME_CHARACTERIZATION_SCRIPT) and ResourceLoader.exists(MILITARY_RUNTIME_CONTROLLER) and ResourceLoader.exists(MILITARY_RUNTIME_WORLD_BRIDGE) and not military_contract.is_empty() and military_controller != null and military_bridge != null
	for military_symbol in ["var military_units := []", "var next_military_unit_uid := 1", "func _summon_military_unit_from_card(", "func _update_military_units(", "func _trigger_military_command("]:
		military_bench_ready = military_bench_ready and not main_source.contains(str(military_symbol))
	for controller_symbol in ["var military_units: Array = []", "func summon_from_card(", "func tick(", "func trigger_command(", "func to_save_data(", "func apply_save_data("]:
		military_bench_ready = military_bench_ready and military_controller_source.contains(str(controller_symbol))
	if military_controller != null:
		var military_debug: Dictionary = military_controller.call("debug_snapshot", -1)
		military_bench_ready = military_bench_ready and bool(military_debug.get("controller_authoritative", false)) and not bool(military_debug.get("parallel_legacy_owner", true)) and _is_pure_data(military_debug)
	_expect(military_bench_ready and main_source.sha256_text() != "22b6579f07eea66a8905ad2ec075b68de1c6d4ad2150a933d44c059164db7c25", "Sprint 47 composes one authoritative MilitaryRuntimeController and non-owning bridge while deleting legacy main.gd military state and algorithms")
	var weather_contract := FileAccess.get_file_as_string(WEATHER_RUNTIME_OWNERSHIP_CONTRACT)
	var weather_characterization_ready := ResourceLoader.exists(WEATHER_RUNTIME_CHARACTERIZATION_BENCH) and ResourceLoader.exists(WEATHER_RUNTIME_CHARACTERIZATION_SCRIPT) and ResourceLoader.exists(WEATHER_RUNTIME_CONTROLLER) and ResourceLoader.exists(WEATHER_RUNTIME_WORLD_BRIDGE) and not weather_contract.is_empty()
	for weather_symbol in ["var weather_forecast := {}", "var active_weather_zones := []", "var weather_sequence := 0", "func _schedule_next_weather_forecast(", "func _activate_weather_forecast(", "func _update_weather_system(", "func _district_weather_multiplier(", "func _apply_weather_control("]:
		weather_characterization_ready = weather_characterization_ready and not main_source.contains(str(weather_symbol))
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	weather_characterization_ready = weather_characterization_ready and coordinator_scene.count("[node name=\"WeatherRuntimeController\"") == 1 and coordinator_scene.count("[node name=\"WeatherRuntimeWorldBridge\"") == 1 and main_source.sha256_text() != "f75b217e85da2e4f5300b900290457d41e4c031ec3c6b7cefe996e6a354a103a"
	_expect(weather_characterization_ready and weather_contract.contains("Current v0.6 status") and weather_contract.contains("Main boundary"), "v0.6 composes one authoritative WeatherRuntimeController and non-owning bridge while keeping the legacy main.gd weather engine deleted")


func _check_product_market_characterization_assets() -> void:
	var ready := ResourceLoader.exists(PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH) and ResourceLoader.exists(PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_SCRIPT) and FileAccess.file_exists(PRODUCT_MARKET_RUNTIME_OWNERSHIP_CONTRACT)
	var packed := load(PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH) as PackedScene
	var bench := packed.instantiate() if packed != null else null
	var manifest: Dictionary = bench.call("build_characterization_manifest_preview") if bench != null and bench.has_method("build_characterization_manifest_preview") else {}
	ready = ready and int(manifest.get("case_count", 0)) == 100 and int(manifest.get("market_case_count", 0)) == 50 and int(manifest.get("historical_case_count", 0)) == 24 and int(manifest.get("cutover_case_count", 0)) == 26 and int(manifest.get("live_case_count", 0)) == 76 and (manifest.get("card_terms_matrix", []) as Array).size() == 12 and (manifest.get("design_decisions", []) as Array).is_empty() and bool(manifest.get("runtime_cutover_enabled", false)) and str(manifest.get("runtime_owner", "")) == "res://scripts/runtime/product_market_runtime_controller.gd" and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var contract := FileAccess.get_file_as_string(PRODUCT_MARKET_RUNTIME_OWNERSHIP_CONTRACT)
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd")
	ready = ready and not main_source.contains("var product_market := {}") and not main_source.contains("var business_cycle_count := 0") and not main_source.contains("var market_timer := 8.0")
	ready = ready and ResourceLoader.exists(PRODUCT_MARKET_RUNTIME_CONTROLLER) and ResourceLoader.exists(PRODUCT_MARKET_RUNTIME_WORLD_BRIDGE) and ResourceLoader.exists("res://resources/finance/product_futures/product_futures_terms_v04_catalog.tres") and controller_source.contains("var product_market: Dictionary = {}") and controller_source.contains("terms_catalog") and not controller_source.contains("clear_futures_for_destroyed_warehouse") and contract.contains("100/100") and contract.contains("76/76") and contract.contains("Sprint 55")
	_expect(ready, "Sprint 55 preserves the authoritative ProductMarketRuntimeController and upgrades the existing gate to 100 records with 76 live aligned")


func _check_city_trade_network_characterization_assets() -> void:
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	var route_source := FileAccess.get_file_as_string("res://scripts/runtime/route_network_runtime_controller.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_runtime_controller.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var ready := ResourceLoader.exists(ROUTE_NETWORK_RUNTIME_CONTROLLER) and ResourceLoader.exists(ROUTE_NETWORK_WORLD_BRIDGE) and ResourceLoader.exists(COMMODITY_FLOW_RUNTIME_CONTROLLER) and ResourceLoader.exists(COMMODITY_FLOW_WORLD_BRIDGE)
	ready = ready and coordinator_scene.contains("RouteNetworkRuntimeController") and coordinator_scene.contains("CommodityFlowRuntimeController") and not coordinator_scene.contains("CityTradeNetworkRuntimeController")
	ready = ready and route_source.contains("func refresh_routes(") and route_source.contains("func to_save_data(") and flow_source.contains("func advance_world(") and flow_source.contains("owns_many_source_many_sink_allocation") and flow_source.contains("owns_sale_receipt_ledger")
	ready = ready and not main_source.contains("func _shortest_trade_path(") and not main_source.contains("func _trade_path_cost(") and not main_source.contains("var city_product_project_sequence")
	_expect(ready, "v0.6 RouteNetwork and CommodityFlow replace the retired project-route/GDP owner without parallel production composition")


func _check_city_development_settlement_characterization_assets() -> void:
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var infrastructure_source := FileAccess.get_file_as_string("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var ready := ResourceLoader.exists(REGION_INFRASTRUCTURE_RUNTIME_CONTROLLER) and ResourceLoader.exists(REGION_INFRASTRUCTURE_WORLD_BRIDGE) and FileAccess.file_exists(REGION_INFRASTRUCTURE_CONTRACT)
	ready = ready and coordinator_scene.contains("RegionInfrastructureRuntimeController") and coordinator_scene.contains("RegionInfrastructureWorldBridge") and not coordinator_scene.contains("CityDevelopmentRuntimeController") and not coordinator_scene.contains("CityDevelopmentWorldBridge")
	ready = ready and infrastructure_source.contains("func apply_facility_action(") and infrastructure_source.contains("func rollback_facility_action(") and infrastructure_source.contains("func finalize_facility_action(") and infrastructure_source.contains("func facility_rollback_atomic_ready(")
	ready = ready and coordinator_source.contains("func play_v06_runtime_card(") and coordinator_source.contains("build_upgrade_or_repair_facility") and not main_source.contains("func _apply_city_development_card(")
	_expect(ready, "RegionInfrastructure and the shared v0.6 CardFlow facade replace the retired CityDevelopment settlement owner")


func _check_city_gdp_derivative_assets() -> void:
	var ready := ResourceLoader.exists(CITY_GDP_DERIVATIVE_RUNTIME_BENCH) and ResourceLoader.exists(CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER) and ResourceLoader.exists(CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE) and ResourceLoader.exists("res://resources/finance/city_gdp_derivatives/city_gdp_derivative_terms_v04_catalog.tres") and FileAccess.file_exists(CITY_GDP_DERIVATIVE_TERMS_CONTRACT)
	var packed := load(CITY_GDP_DERIVATIVE_RUNTIME_BENCH) as PackedScene
	var bench := packed.instantiate() if packed != null else null
	var manifest: Dictionary = bench.call("build_runtime_manifest_preview") if bench != null and bench.has_method("build_runtime_manifest_preview") else {}
	ready = ready and int(manifest.get("case_count", 0)) == 40 and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/city_gdp_derivative_runtime_controller.gd")
	ready = ready and not main_source.contains("gdp_bet_") and not main_source.contains("func _apply_city_gdp_derivative(") and not main_source.contains("func _resolve_city_gdp_derivatives(")
	ready = ready and main_source.contains("city_gdp_derivative_runtime") and controller_source.contains("positions_by_district") and controller_source.contains("func open_position(") and controller_source.contains("func settle_destroyed_city(") and controller_source.contains("func apply_save_data(")
	_expect(ready, "City GDP Derivative v0.4 uses one Resource-backed Controller, a non-owning WorldBridge, and a 40-case alignment gate without a parallel main.gd engine")


func _check_runtime_card_catalog_resource_assets() -> void:
	var required_assets := [
		RUNTIME_CARD_CATALOG_RESOURCE_BENCH,
		RUNTIME_CARD_CATALOG_RESOURCE_SCRIPT,
		CARD_RUNTIME_CATALOG_SERVICE,
		CARD_RUNTIME_DEFINITION_WORLD_BRIDGE,
		CARD_RUNTIME_CATALOG_RESOURCE,
		CARD_RUNTIME_CATALOG_INTEGRITY,
		RUNTIME_CARD_CATALOG_OWNERSHIP_CONTRACT,
		RUNTIME_CARD_CATALOG_RESOURCE_SCHEMA,
	]
	var ready := true
	for path in required_assets:
		ready = ready and (ResourceLoader.exists(path) or FileAccess.file_exists(path))
	var packed := load(RUNTIME_CARD_CATALOG_RESOURCE_BENCH) as PackedScene
	var bench := packed.instantiate() if packed != null else null
	var manifest: Dictionary = bench.call("build_resource_manifest_preview") if bench != null and bench.has_method("build_resource_manifest_preview") else {}
	var schema: Dictionary = bench.call("resource_schema_preview") if bench != null and bench.has_method("resource_schema_preview") else {}
	ready = ready and bench != null and bench.has_method("historical_integrity_cases") and bench.has_method("live_cutover_cases") and bench.has_method("run_resource_suite")
	ready = ready and int(manifest.get("case_count", 0)) == 80 and int(manifest.get("historical_case_count", 0)) == 40 and int(manifest.get("live_case_count", 0)) == 40
	ready = ready and bool(schema.get("runtime_cutover_enabled", false)) and str(manifest.get("runtime_owner", "")) == "CardRuntimeCatalogService" and str(schema.get("runtime_owner", "")) == "CardRuntimeCatalogService"
	ready = ready and int(schema.get("family_resources", 0)) == 113 and int(schema.get("embedded_rank_resources", 0)) == 230 and int(schema.get("pack_resources", 0)) == 10
	ready = ready and _is_pure_data(manifest) and _is_pure_data(schema)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var ownership_contract := FileAccess.get_file_as_string(RUNTIME_CARD_CATALOG_OWNERSHIP_CONTRACT)
	var resource_schema := FileAccess.get_file_as_string(RUNTIME_CARD_CATALOG_RESOURCE_SCHEMA)
	for legacy_constant in ["SKILL_CATALOG", "UPGRADEABLE_SKILL_FAMILIES", "COMMON_CARD_POOL"]:
		ready = ready and not main_source.contains("const %s" % legacy_constant)
	for legacy_helper in ["_skill_exists", "_skill_definition", "_derived_rank_skill_definition", "_skill_rank", "_skill_family"]:
		ready = ready and not main_source.contains("func %s(" % legacy_helper)
	var coordinator_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	ready = ready and coordinator_source.contains("CardRuntimeCatalogService") and coordinator_source.contains("CardRuntimeDefinitionWorldBridge")
	ready = ready and ownership_contract.contains("80/80") and ownership_contract.contains("CardRuntimeCatalogService") and resource_schema.contains("113 `CardRuntimeFamilyResource`") and resource_schema.contains("230 embedded `CardRuntimeRankResource`")
	_expect(ready, "Sprint 58 uses one Inspector-editable 113-family/230-rank Resource catalog, an authoritative Catalog Service, and no parallel main.gd catalog owner")


func _check_runtime_card_authoring_assets() -> void:
	var required_assets := [RUNTIME_CARD_AUTHORING_WORKSPACE, RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH, RUNTIME_CARD_AUTHORING_SERVICE, RUNTIME_CARD_AUTHORING_INSPECTOR_PLUGIN, RUNTIME_CARD_AUTHORING_WORKFLOW_DOC]
	var ready := true
	for path in required_assets:
		ready = ready and (ResourceLoader.exists(path) or FileAccess.file_exists(path))
	var bench_packed := load(RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH) as PackedScene
	var bench := bench_packed.instantiate() if bench_packed != null else null
	var manifest: Dictionary = bench.call("build_authoring_manifest_preview") if bench != null and bench.has_method("build_authoring_manifest_preview") else {}
	ready = ready and bench != null and bench.has_method("authoring_cases") and bench.has_method("run_authoring_suite") and int(manifest.get("case_count", 0)) == 36 and str(manifest.get("runtime_owner", "")) == "CardRuntimeCatalogService" and bool(manifest.get("editor_only", false)) and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var main_scene_source := FileAccess.get_file_as_string(MAIN_SCENE)
	var coordinator_scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var main_script_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	ready = ready and not main_scene_source.contains("RuntimeCardAuthoring") and not coordinator_scene_source.contains("RuntimeCardAuthoring") and not main_script_source.contains("CardRuntimeAuthoringService")
	var plugin_source := FileAccess.get_file_as_string("res://addons/space_syndicate_design_qa/space_syndicate_design_qa_plugin.gd")
	ready = ready and plugin_source.contains("add_inspector_plugin") and plugin_source.contains("card_runtime_authoring_inspector_plugin.gd")
	var workflow_doc := FileAccess.get_file_as_string(RUNTIME_CARD_AUTHORING_WORKFLOW_DOC)
	ready = ready and workflow_doc.contains("36/36") and workflow_doc.contains("editor-only") and workflow_doc.contains("CardRuntimeCatalogService")
	_expect(ready, "Sprint 59 provides Inspector validation, Workspace navigation, and user-scoped change review while staying outside main/Coordinator runtime composition")


func _check_ruleset_v05_foundation_assets() -> void:
	var required_assets := [
		RULESET_V05_PROFILE,
		PRODUCT_INDUSTRY_CATALOG_V05,
		CARD_RUNTIME_CATALOG_V05,
		CLOCK_DOMAIN_REGISTRY_V05,
		RULESET_SAVE_HANDSHAKE_V05,
		RULESET_V05_FOUNDATION_BENCH,
	]
	var ready := true
	for path in required_assets:
		ready = ready and ResourceLoader.exists(path)
	var profile := load(RULESET_V05_PROFILE)
	var product_catalog := load(PRODUCT_INDUSTRY_CATALOG_V05)
	var card_catalog := load(CARD_RUNTIME_CATALOG_V05)
	var clock_registry := load(CLOCK_DOMAIN_REGISTRY_V05)
	var profile_snapshot: Dictionary = profile.call("debug_snapshot") if profile != null and profile.has_method("debug_snapshot") else {}
	var product_snapshot: Dictionary = product_catalog.call("debug_snapshot") if product_catalog != null and product_catalog.has_method("debug_snapshot") else {}
	var card_snapshot: Dictionary = card_catalog.call("debug_snapshot") if card_catalog != null and card_catalog.has_method("debug_snapshot") else {}
	var clock_snapshot: Dictionary = clock_registry.call("debug_snapshot") if clock_registry != null and clock_registry.has_method("debug_snapshot") else {}
	ready = ready and str((profile_snapshot.get("identity", {}) as Dictionary).get("ruleset_id", "")) == "v0.5"
	ready = ready and int((profile_snapshot.get("identity", {}) as Dictionary).get("currency_scale", 0)) == 100
	ready = ready and (product_snapshot.get("industries", []) as Array).size() == 6 and (product_snapshot.get("products", []) as Array).size() == 46
	ready = ready and str(card_snapshot.get("schema_version", "")) == "v0.5" and (card_snapshot.get("release_ready_card_ids", []) as Array).is_empty()
	ready = ready and (clock_snapshot.get("timers", []) as Array).size() == 14
	ready = ready and _is_pure_data(profile_snapshot) and _is_pure_data(product_snapshot) and _is_pure_data(card_snapshot) and _is_pure_data(clock_snapshot)
	var handshake_packed := load(RULESET_SAVE_HANDSHAKE_V05) as PackedScene
	var handshake := handshake_packed.instantiate() if handshake_packed != null else null
	var handshake_snapshot: Dictionary = handshake.call("debug_snapshot") if handshake != null and handshake.has_method("debug_snapshot") else {}
	ready = ready and handshake != null and handshake.has_method("inspect_envelope") and handshake.has_method("validate_v06_envelope") and handshake.has_method("compose_v06_envelope") and handshake.has_method("write_authorization")
	ready = ready and str(handshake_snapshot.get("service_id", "")) == "ruleset_save_handshake_v06" and int(handshake_snapshot.get("save_version", 0)) == 3 and bool(handshake_snapshot.get("registry_valid", false)) and not bool(handshake_snapshot.get("production_save_path_owned", true)) and _is_pure_data(handshake_snapshot)
	if handshake != null:
		handshake.free()
	var bench_packed := load(RULESET_V05_FOUNDATION_BENCH) as PackedScene
	var bench := bench_packed.instantiate() if bench_packed != null else null
	var manifest: Dictionary = bench.call("build_foundation_manifest_preview") if bench != null and bench.has_method("build_foundation_manifest_preview") else {}
	ready = ready and bench != null and bench.has_method("foundation_cases") and bench.has_method("run_foundation_suite")
	ready = ready and int(manifest.get("record_count", 0)) == 56 and (manifest.get("records", []) as Array).size() == 56 and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/ruleset_runtime_bridge.gd")
	var save_source := FileAccess.get_file_as_string("res://scripts/runtime/game_save_runtime_coordinator.gd")
	var catalog_source := FileAccess.get_file_as_string("res://scripts/runtime/card_runtime_catalog_service.gd") + FileAccess.get_file_as_string("res://scenes/runtime/CardRuntimeCatalogService.tscn")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	ready = ready and bridge_source.contains("space_syndicate_ruleset_v04.tres") and not bridge_source.contains("space_syndicate_ruleset_v05.tres")
	ready = ready and save_source.contains("const CURRENT_SAVE_VERSION := 3")
	ready = ready and catalog_source.contains("card_runtime_catalog_v04.tres") and not catalog_source.contains("card_runtime_catalog_v05.tres")
	ready = ready and not main_source.contains("space_syndicate_ruleset_v05") and not main_source.contains("RulesetSaveHandshakeService")
	_expect(ready, "SS05-01 pure-data v0.5 artifacts coexist with the v0.4 runtime rules/catalog and fail-closed v3 save handshake")


func _check_player_text_v05_foundation_assets() -> void:
	var required_assets := [
		PLAYER_TEXT_V05_SCHEMA,
		PLAYER_TEXT_V05_UNIT_CATALOG,
		PLAYER_TEXT_V05_TRANSLATION,
		PLAYER_TEXT_V05_MIGRATION_REGISTRY,
		PLAYER_TEXT_V05_FOUNDATION_BENCH,
	]
	var ready := true
	for path in required_assets:
		ready = ready and ResourceLoader.exists(path)
	var text_catalog := load(PLAYER_TEXT_V05_SCHEMA)
	var unit_catalog := load(PLAYER_TEXT_V05_UNIT_CATALOG)
	var migration_registry := load(PLAYER_TEXT_V05_MIGRATION_REGISTRY)
	var text_snapshot: Dictionary = text_catalog.call("debug_snapshot") if text_catalog != null and text_catalog.has_method("debug_snapshot") else {}
	var unit_snapshot: Dictionary = unit_catalog.call("debug_snapshot") if unit_catalog != null and unit_catalog.has_method("debug_snapshot") else {}
	var migration_validation: Dictionary = migration_registry.call("validation_snapshot") if migration_registry != null and migration_registry.has_method("validation_snapshot") else {}
	ready = ready and _is_pure_data(text_snapshot) and (unit_snapshot.get("entries", []) as Array).size() == 4 and _is_pure_data(unit_snapshot)
	ready = ready and bool(migration_validation.get("valid", false)) and int(migration_validation.get("entry_count", 0)) == 239 and int(migration_validation.get("release_ready_count", -1)) == 0 and int(migration_validation.get("blocked_count", 0)) == 239
	var bench_packed := load(PLAYER_TEXT_V05_FOUNDATION_BENCH) as PackedScene
	var bench := bench_packed.instantiate() if bench_packed != null else null
	var manifest: Dictionary = bench.call("build_foundation_manifest_preview") if bench != null and bench.has_method("build_foundation_manifest_preview") else {}
	ready = ready and bench != null and bench.has_method("foundation_cases") and bench.has_method("run_foundation_suite")
	ready = ready and int(manifest.get("record_count", 0)) == 48 and (manifest.get("records", []) as Array).size() == 48 and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/ruleset_runtime_bridge.gd")
	var catalog_source := FileAccess.get_file_as_string("res://scripts/runtime/card_runtime_catalog_service.gd") + FileAccess.get_file_as_string("res://scenes/runtime/CardRuntimeCatalogService.tscn")
	var save_source := FileAccess.get_file_as_string("res://scripts/runtime/game_save_runtime_coordinator.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	ready = ready and bridge_source.contains("space_syndicate_ruleset_v04.tres") and not bridge_source.contains("player_text_v05")
	ready = ready and catalog_source.contains("card_runtime_catalog_v04.tres") and not catalog_source.contains("player_text_v05")
	ready = ready and save_source.contains("const CURRENT_SAVE_VERSION := 3") and not save_source.contains("PlayerText")
	ready = ready and not main_source.contains("PlayerTextV05") and not main_source.contains("player_text_schema_v05")
	_expect(ready, "SS05-01A provides a pure-data player-text foundation and 239-card migration registry without cutting production v0.4 text ownership")


func _check_victory_control_runtime_assets() -> void:
	var ready := ResourceLoader.exists(VICTORY_CONTROL_RUNTIME_CONTROLLER) and ResourceLoader.exists(VICTORY_CONTROL_WORLD_BRIDGE) and ResourceLoader.exists(VICTORY_CONTROL_RUNTIME_BENCH) and FileAccess.file_exists(VICTORY_CONTROL_RUNTIME_CONTRACT)
	var controller_packed := load(VICTORY_CONTROL_RUNTIME_CONTROLLER) as PackedScene
	var controller := controller_packed.instantiate() if controller_packed != null else null
	var configured: Dictionary = controller.call("configure") if controller != null else {}
	ready = ready and bool(configured.get("configured", false)) and str(configured.get("ruleset_id", "")) == "v0.6"
	ready = ready and controller != null and controller.has_method("evaluate_region_control") and controller.has_method("evaluate_candidates") and controller.has_method("advance_world_effective") and controller.has_method("resolve_special_outcome") and controller.has_method("to_save_data") and controller.has_method("apply_save_data")
	if controller != null:
		controller.free()
	var bench_packed := load(VICTORY_CONTROL_RUNTIME_BENCH) as PackedScene
	var bench := bench_packed.instantiate() if bench_packed != null else null
	var manifest: Dictionary = bench.call("build_victory_manifest_preview") if bench != null and bench.has_method("build_victory_manifest_preview") else {}
	ready = ready and bench != null and bench.has_method("victory_cases") and bench.has_method("run_victory_suite") and int(manifest.get("record_count", 0)) == 54 and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for forbidden in ["var game_over", "victory_countdown", "_roguelike_cash_goal", "_player_visible_settlement_estimate", "_player_final_score", "_final_score_rankings", "CITY_FINAL_VALUE"]:
		ready = ready and not main_source.contains(str(forbidden))
	var contract := FileAccess.get_file_as_string(VICTORY_CONTROL_RUNTIME_CONTRACT)
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	ready = ready and coordinator_scene.contains("VictoryControlRuntimeController") and coordinator_scene.contains("VictoryControlWorldBridge") and contract.contains("SS06-05 is a hard cutover") and contract.contains("no runtime fallback")
	_expect(ready, "SS06-05 composes the unique v0.6 Victory owner and non-owning world bridge with no fixed-depth or cash-goal fallback")


func _check_industry_capacity_card_group_runtime_assets() -> void:
	var ready := ResourceLoader.exists(PLAYER_MANA_RUNTIME_CONTROLLER) and ResourceLoader.exists(COMMODITY_FLOW_RUNTIME_CONTROLLER)
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	var asset_source := FileAccess.get_file_as_string("res://scripts/runtime/player_mana_runtime_controller.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_runtime_controller.gd")
	var queue_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
	ready = ready and coordinator_scene.contains("PlayerManaRuntimeController") and coordinator_scene.contains("CommodityFlowRuntimeController") and not coordinator_scene.contains("IndustryCapacityRuntimeService") and not coordinator_scene.contains("IndustryCapacityWorldBridge")
	ready = ready and asset_source.contains("asset_balance_authority") and asset_source.contains("legacy_industry_capacity_fallback_used") and flow_source.contains("owns_fixed_point_flow") and flow_source.contains("owns_sale_receipt_ledger")
	ready = ready and queue_source.contains('"asset_reservation_authority": false') and queue_source.contains('"priority_bid_authority": false') and queue_source.contains('entry.erase("capacity_reservation")')
	_expect(ready, "PlayerMana and CommodityFlow replace the retired IndustryCapacity owner while the card-group queue keeps its narrow reservation boundary")


func _check_ruleset_v06_region_infrastructure_foundation_assets() -> void:
	var required_assets := [
		RULESET_V06_PROFILE,
		RULESET_V06_SCHEMA_REGISTRY,
		RULESET_V06_CONFORMANCE_REGISTRY,
		REGION_INFRASTRUCTURE_CHARACTERIZATION_BENCH,
		REGION_INFRASTRUCTURE_CHARACTERIZATION_REGISTRY,
	]
	var ready := true
	for path in required_assets:
		ready = ready and ResourceLoader.exists(path)
	ready = ready and FileAccess.file_exists(REGION_INFRASTRUCTURE_CONTRACT)
	var profile := load(RULESET_V06_PROFILE)
	var profile_snapshot: Dictionary = profile.call("debug_snapshot") if profile != null and profile.has_method("debug_snapshot") else {}
	ready = ready and str((profile_snapshot.get("identity", {}) as Dictionary).get("ruleset_id", "")) == "v0.6"
	ready = ready and int((profile_snapshot.get("infrastructure", {}) as Dictionary).get("maximum_facility_rank", 0)) == 4
	ready = ready and not JSON.stringify(profile_snapshot).to_lower().contains("panic") and not JSON.stringify(profile_snapshot).to_lower().contains("\"heat")
	ready = ready and _is_pure_data(profile_snapshot)
	var bench_packed := load(REGION_INFRASTRUCTURE_CHARACTERIZATION_BENCH) as PackedScene
	var bench := bench_packed.instantiate() if bench_packed != null else null
	var manifest: Dictionary = bench.call("build_characterization_manifest_preview") if bench != null and bench.has_method("build_characterization_manifest_preview") else {}
	ready = ready and bench != null and bench.has_method("characterization_cases") and bench.has_method("run_characterization_suite")
	ready = ready and int(manifest.get("case_count", 0)) == 68 and (manifest.get("records", []) as Array).size() == 68 and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var conformance_script := load(RULESET_V06_CONFORMANCE_REGISTRY) as Script
	var conformance: RefCounted = conformance_script.new() if conformance_script != null else null
	var conformance_snapshot: Dictionary = conformance.call("debug_snapshot") if conformance != null else {}
	ready = ready and str(conformance_snapshot.get("ruleset_id", "")) == "v0.6" and _is_pure_data(conformance_snapshot)
	var region_registry_script := load(REGION_INFRASTRUCTURE_CHARACTERIZATION_REGISTRY) as Script
	var region_registry: RefCounted = region_registry_script.new() if region_registry_script != null else null
	var region_snapshot: Dictionary = region_registry.call("debug_snapshot") if region_registry != null else {}
	ready = ready and not bool((region_snapshot.get("legacy_heat_deletion_gate", {}) as Dictionary).get("v06_heat_state_allowed", true)) and (region_snapshot.get("legacy_heat_ownership", []) as Array).size() >= 6 and _is_pure_data(region_snapshot)
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var ruleset_scene := FileAccess.get_file_as_string("res://scenes/runtime/RulesetRuntimeBridge.tscn")
	var catalog_scene := FileAccess.get_file_as_string("res://scenes/runtime/CardRuntimeCatalogService.tscn")
	var save_source := FileAccess.get_file_as_string("res://scripts/runtime/game_save_runtime_coordinator.gd")
	ready = ready and ruleset_scene.contains("space_syndicate_ruleset_v04.tres") and not ruleset_scene.contains("space_syndicate_ruleset_v06.tres")
	ready = ready and catalog_scene.contains("card_runtime_catalog_v04.tres") and not catalog_scene.contains("v06")
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	ready = ready and save_source.contains("const CURRENT_SAVE_VERSION := 3")
	ready = ready and coordinator_scene.contains("RegionInfrastructureRuntimeController") and coordinator_scene.contains("CommodityFlowRuntimeController") and coordinator_scene.contains("CommodityCardInventoryRuntimeController") and coordinator_scene.contains("CardPlayerStateProductionAdapterV06") and not coordinator_scene.contains("CommodityCardInventoryWorldBridge")
	ready = ready and coordinator_source.contains("func refresh_v06_production_player_bindings(") and coordinator_source.contains("func play_v06_runtime_card(") and main_source.contains("func _play_v06_runtime_card_for_player(")
	var contract := FileAccess.get_file_as_string(REGION_INFRASTRUCTURE_CONTRACT)
	ready = ready and contract.contains("Legacy Heat / Panic Retirement") and contract.contains("No parallel fallback") and contract.contains("active `GameRuntimeCoordinator` composition no longer instances `CityDevelopmentRuntimeController`")
	_expect(ready, "the v0.4 global namespace and v3 save boundary coexist with one explicit v0.6 transaction/infrastructure production graph")


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _is_pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
	elif value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("MAIN RUNTIME COMPOSITION: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("MAIN RUNTIME COMPOSITION PASS")
		quit(0)
		return
	print("MAIN RUNTIME COMPOSITION FAIL: %d" % failures.size())
	quit(1)
