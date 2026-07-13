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
const CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE := "res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn"
const CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE := "res://scenes/runtime/CardPlayEligibilityWorldBridge.tscn"
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
const CONTRACT_RUNTIME_CHARACTERIZATION_BENCH := "res://scenes/tools/ContractRuntimeCharacterizationBench.tscn"
const CONTRACT_RUNTIME_CHARACTERIZATION_SCRIPT := "res://scripts/tools/contract_runtime_characterization_bench.gd"
const CONTRACT_RUNTIME_OWNERSHIP_CONTRACT := "res://docs/contract_runtime_ownership_contract.md"
const CONTRACT_RUNTIME_CONTROLLER := "res://scenes/runtime/ContractRuntimeController.tscn"
const CONTRACT_RUNTIME_WORLD_BRIDGE := "res://scenes/runtime/ContractRuntimeWorldBridge.tscn"
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
const GLOBAL_UI_NAVIGATION_CHARACTERIZATION_REGISTRY := "res://scripts/tools/global_ui_navigation_characterization_registry.gd"
const GLOBAL_UI_NAVIGATION_RUNTIME_CONTRACT := "res://docs/global_ui_navigation_runtime_contract.md"
const MENU_SHELL_RUNTIME_CUTOVER_BENCH := "res://scenes/tools/MenuShellRuntimeCutoverBench.tscn"
const RULESET_V05_PROFILE := "res://resources/rules/space_syndicate_ruleset_v05.tres"
const PRODUCT_INDUSTRY_CATALOG_V05 := "res://resources/content/product_industry_catalog_v05.tres"
const CARD_RUNTIME_CATALOG_V05 := "res://resources/cards/runtime/card_runtime_catalog_v05.tres"
const CLOCK_DOMAIN_REGISTRY_V05 := "res://resources/rules/clock_domain_registry_v05.tres"
const RULESET_SAVE_HANDSHAKE_V05 := "res://scenes/runtime/RulesetSaveHandshakeService.tscn"
const RULESET_V05_FOUNDATION_BENCH := "res://scenes/tools/RulesetV05FoundationBench.tscn"

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
	_check_global_ui_navigation_characterization_assets()
	_check_ruleset_v05_foundation_assets()
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
		"RuntimeServices/TableAudioHost",
		"RuntimeServices/RuntimeControllerHost",
		"RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityDevelopmentRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityDevelopmentWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardRuntimeCatalogService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardRuntimeDefinitionWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeWorldBridge",
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
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectWorldBridge",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseSettlementRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplySnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyCashflowRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ScenarioRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyDashboardPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/StandingsPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FinalSettlementPublicSnapshotService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/IntelDossierPublicSnapshotService",
		"RuntimeServices/RuntimeFallbackHost",
	]:
		_expect(main.get_node_or_null(node_path) != null, "main.tscn owns %s" % node_path)
	var screen := main.get_node_or_null("RuntimeGameScreen") as Control
	_expect(screen != null and screen.scene_file_path == "res://scenes/ui/GameScreen.tscn", "RuntimeGameScreen is the editable GameScreen scene instance")
	for node_name in ["TopBar", "PublicTrack", "PlanetBoard", "PlanetMapView", "RightInspector", "PlayerBoard", "OverlayLayer"]:
		_expect(screen != null and screen.find_child(node_name, true, false) != null, "RuntimeGameScreen contains %s" % node_name)
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
	var card_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController")
	_expect(card_controller != null and card_controller.scene_file_path == "res://scenes/runtime/CardResolutionRuntimeController.tscn", "RuntimeControllerHost owns the editable CardResolutionRuntimeController scene")
	_expect(card_controller != null and card_controller.has_method("tick") and card_controller.has_method("to_save_data") and card_controller.has_method("debug_snapshot"), "CardResolutionRuntimeController exposes timing, save, and debug APIs")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var city_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityDevelopmentRuntimeController")
	var city_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityDevelopmentWorldBridge")
	_expect(city_controller != null and city_controller.scene_file_path == "res://scenes/runtime/CityDevelopmentRuntimeController.tscn", "GameRuntimeCoordinator owns the editable CityDevelopmentRuntimeController scene")
	_expect(city_controller != null and city_controller.has_method("evaluate_development_request") and city_controller.has_method("plan_settlement") and city_controller.has_method("validate_settlement_plan") and city_controller.has_method("finalize_settlement") and city_controller.has_method("debug_snapshot"), "CityDevelopmentRuntimeController exposes legality, planning, lifecycle, and debug APIs")
	_expect(city_world_bridge != null and city_world_bridge.scene_file_path == "res://scenes/runtime/CityDevelopmentWorldBridge.tscn" and city_world_bridge.has_method("capture_settlement_facts") and city_world_bridge.has_method("preflight_settlement") and city_world_bridge.has_method("apply_settlement_plan"), "GameRuntimeCoordinator owns the non-owning CityDevelopmentWorldBridge scene")
	var balance_diagnostics := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsRuntimeService")
	var balance_diagnostics_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameplayBalanceDiagnosticsWorldBridge")
	var ai_runtime_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	var ai_runtime_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeWorldBridge")
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
	var card_resolution_execution := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService")
	var card_resolution_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionWorldBridge")
	var economy_product_route_effect := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectRuntimeService")
	var economy_product_route_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteEffectWorldBridge")
	var economy_product_route_formula := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService")
	var product_market_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	var product_market_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeWorldBridge")
	var city_gdp_derivative_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityGdpDerivativeRuntimeController")
	var city_gdp_derivative_world_bridge := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityGdpDerivativeRuntimeWorldBridge")
	var hand_interaction := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/PlayerHandInteractionRuntimeService")
	var purchase_settlement := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseSettlementRuntimeService")
	var district_supply_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictSupplySnapshotService")
	var economy := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyCashflowRuntimeController")
	var gdp_formula := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController")
	var scenario := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ScenarioRuntimeController")
	var first_table_authored := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FirstTableAuthoredRuntimeService")
	var codex_navigation := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController")
	var codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexPublicSnapshotService")
	var monster_codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSnapshotService")
	var product_codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSnapshotService")
	var card_codex_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSnapshotService")
	var economy_dashboard_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyDashboardPublicSnapshotService")
	var standings_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/StandingsPublicSnapshotService")
	var final_settlement_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FinalSettlementPublicSnapshotService")
	var intel_dossier_public_snapshot := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/IntelDossierPublicSnapshotService")
	_expect(coordinator != null and coordinator.scene_file_path == "res://scenes/runtime/GameRuntimeCoordinator.tscn" and coordinator.has_method("active_forced_decision") and coordinator.has_method("debug_snapshot"), "RuntimeControllerHost owns the editable GameRuntimeCoordinator scene")
	_expect(balance_diagnostics != null and balance_diagnostics.scene_file_path == GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE and balance_diagnostics.has_method("development_routes") and balance_diagnostics.has_method("card_budget_report") and balance_diagnostics.has_method("build_balance_report") and balance_diagnostics.has_method("build_developer_panel_snapshot"), "GameRuntimeCoordinator owns the read-only GameplayBalanceDiagnosticsRuntimeService scene")
	_expect(balance_diagnostics_world_bridge != null and balance_diagnostics_world_bridge.scene_file_path == GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE and balance_diagnostics_world_bridge.has_method("bind_world") and balance_diagnostics_world_bridge.has_method("build_world_snapshot") and balance_diagnostics_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-mutating GameplayBalanceDiagnosticsWorldBridge scene")
	var diagnostics_debug: Dictionary = balance_diagnostics.call("debug_snapshot") if balance_diagnostics != null else {}
	_expect(int(diagnostics_debug.get("route_count", 0)) == 7 and str(diagnostics_debug.get("runtime_balance_model_owner", "")) == "res://scripts/balance/runtime_balance_model.gd" and not bool(diagnostics_debug.get("formula_authority", true)) and not bool(diagnostics_debug.get("world_mutation_authority", true)), "diagnostics service uses seven route Resources while RuntimeBalanceModel remains formula owner")
	var route_catalog := load(DEVELOPMENT_ROUTE_CATALOG)
	var route_validation: Dictionary = route_catalog.call("validation_report") if route_catalog != null and route_catalog.has_method("validation_report") else {}
	_expect(bool(route_validation.get("valid", false)) and int(route_validation.get("route_count", 0)) == 7, "v0.4 Development Route Catalog is valid and Inspector editable")
	_expect(ai_runtime_controller != null and ai_runtime_controller.scene_file_path == AI_RUNTIME_CONTROLLER and ai_runtime_controller.has_method("build_turn_plan") and ai_runtime_controller.has_method("build_response_plan") and ai_runtime_controller.has_method("to_save_data") and ai_runtime_controller.has_method("policy_snapshot"), "GameRuntimeCoordinator owns the authoritative AiRuntimeController scene")
	_expect(ai_runtime_world_bridge != null and ai_runtime_world_bridge.scene_file_path == AI_RUNTIME_WORLD_BRIDGE and ai_runtime_world_bridge.has_method("bind_world") and ai_runtime_world_bridge.has_method("route_intent") and ai_runtime_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the stateless AiRuntimeWorldBridge scene")
	_expect(card_presentation != null and card_presentation.scene_file_path == CARD_PRESENTATION_RUNTIME_SERVICE and card_presentation.has_method("compose_card") and card_presentation.has_method("compose_hand_card") and card_presentation.has_method("compose_resolution") and card_presentation.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the authoritative CardPresentationRuntimeService scene")
	_expect(table_viewmodel != null and table_viewmodel.scene_file_path == GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE and table_viewmodel.has_method("compose_table") and table_viewmodel.has_method("compose_card_surfaces") and table_viewmodel.has_method("compose_resolution_overlay_badges") and table_viewmodel.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the authoritative GameTableViewModelRuntimeService scene")
	_expect(card_play_eligibility != null and card_play_eligibility.scene_file_path == CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE and card_play_eligibility.has_method("evaluate_play") and card_play_eligibility.has_method("evaluate_hand") and card_play_eligibility.has_method("requirement_status") and card_play_eligibility.has_method("target_status"), "GameRuntimeCoordinator owns the authoritative CardPlayEligibilityRuntimeService scene")
	_expect(card_play_world_bridge != null and card_play_world_bridge.scene_file_path == CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE and card_play_world_bridge.has_method("build_facts") and card_play_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the read-only CardPlayEligibilityWorldBridge scene")
	_expect(scheduler != null and scheduler.scene_file_path == "res://scenes/runtime/ForcedDecisionRuntimeScheduler.tscn" and scheduler.has_method("active_decision") and scheduler.has_method("blocks_card_resolution"), "GameRuntimeCoordinator owns the editable ForcedDecisionRuntimeScheduler scene")
	_expect(session != null and session.scene_file_path == "res://scenes/runtime/GameSessionRuntimeController.tscn" and session.has_method("begin_session") and session.has_method("request_save") and session.has_method("request_load"), "GameRuntimeCoordinator owns the editable GameSessionRuntimeController scene")
	_expect(save != null and save.scene_file_path == "res://scenes/runtime/GameSaveRuntimeCoordinator.tscn" and save.has_method("write_save") and save.has_method("read_save") and save.has_method("operation_snapshot"), "GameSessionRuntimeController owns the editable GameSaveRuntimeCoordinator scene")
	_expect(purchase != null and purchase.scene_file_path == "res://scenes/runtime/DistrictPurchaseRuntimeController.tscn" and purchase.has_method("open_window") and purchase.has_method("authorize_purchase") and purchase.has_method("to_legacy_save_snapshot"), "GameRuntimeCoordinator owns the editable DistrictPurchaseRuntimeController scene")
	_expect(card_inventory != null and card_inventory.scene_file_path == "res://scenes/runtime/CardInventoryRuntimeService.tscn" and card_inventory.has_method("plan_receive") and card_inventory.has_method("commit_receive") and card_inventory.has_method("plan_remove") and card_inventory.has_method("commit_remove") and card_inventory.has_method("plan_lock") and card_inventory.has_method("commit_lock") and card_inventory.has_method("plan_transfer") and card_inventory.has_method("commit_transfer") and card_inventory.has_method("inventory_fingerprint"), "GameRuntimeCoordinator owns the editable CardInventoryRuntimeService scene and complete slot-mutation API")
	_expect(card_resolution_queue != null and card_resolution_queue.scene_file_path == "res://scenes/runtime/CardResolutionQueueRuntimeService.tscn" and card_resolution_queue.has_method("plan_submission") and card_resolution_queue.has_method("commit_submission") and card_resolution_queue.has_method("lock_batch") and card_resolution_queue.has_method("start_next") and card_resolution_queue.has_method("complete_active") and card_resolution_queue.has_method("promote_next_batch") and card_resolution_queue.has_method("to_legacy_save_snapshot") and card_resolution_queue.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable CardResolutionQueueRuntimeService scene and complete queue-lifecycle API")
	_expect(card_resolution_execution != null and card_resolution_execution.scene_file_path == CARD_RESOLUTION_EXECUTION_SERVICE and card_resolution_execution.has_method("plan_execution") and card_resolution_execution.has_method("advance_execution") and card_resolution_execution.has_method("finalize_execution") and card_resolution_execution.has_method("recover_from_active") and card_resolution_execution.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable CardResolutionExecutionRuntimeService scene and execution-transaction API")
	_expect(card_resolution_world_bridge != null and card_resolution_world_bridge.scene_file_path == CARD_RESOLUTION_EXECUTION_WORLD_BRIDGE and card_resolution_world_bridge.has_method("apply_intent") and card_resolution_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the stateless CardResolutionExecutionWorldBridge scene")
	_expect(economy_product_route_effect != null and economy_product_route_effect.scene_file_path == CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_SERVICE and economy_product_route_effect.has_method("supports_handler") and economy_product_route_effect.has_method("plan_effect") and economy_product_route_effect.has_method("finalize_effect") and economy_product_route_effect.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable economy/product/route effect-family service")
	_expect(economy_product_route_bridge != null and economy_product_route_bridge.scene_file_path == CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_WORLD_BRIDGE and economy_product_route_bridge.has_method("apply_effect") and economy_product_route_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the stateless economy/product/route world bridge")
	_expect(economy_product_route_formula != null and economy_product_route_formula.scene_file_path == CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE and economy_product_route_formula.has_method("supported_formulas") and economy_product_route_formula.has_method("calculate") and economy_product_route_formula.has_method("formula_ownership_snapshot") and economy_product_route_formula.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable pure economy/product/route Formula Service")
	_expect(product_market_controller != null and product_market_controller.scene_file_path == PRODUCT_MARKET_RUNTIME_CONTROLLER and product_market_controller.has_method("refresh_prices") and product_market_controller.has_method("market_tick") and product_market_controller.has_method("terms_for_card_id") and product_market_controller.has_method("open_futures_position") and product_market_controller.has_method("settle_futures_for_destroyed_warehouse") and product_market_controller.has_method("to_save_data") and product_market_controller.has_method("apply_save_data"), "GameRuntimeCoordinator owns the authoritative Resource-backed ProductMarketRuntimeController scene")
	_expect(product_market_world_bridge != null and product_market_world_bridge.scene_file_path == PRODUCT_MARKET_RUNTIME_WORLD_BRIDGE and product_market_world_bridge.has_method("bind_world") and product_market_world_bridge.has_method("shared_rng") and product_market_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-owning ProductMarketRuntimeWorldBridge scene")
	_expect(city_gdp_derivative_controller != null and city_gdp_derivative_controller.scene_file_path == CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER and city_gdp_derivative_controller.has_method("open_position") and city_gdp_derivative_controller.has_method("settle_district") and city_gdp_derivative_controller.has_method("settle_destroyed_city") and city_gdp_derivative_controller.has_method("to_save_data") and city_gdp_derivative_controller.has_method("apply_save_data"), "GameRuntimeCoordinator owns the authoritative Resource-backed CityGdpDerivativeRuntimeController scene")
	_expect(city_gdp_derivative_world_bridge != null and city_gdp_derivative_world_bridge.scene_file_path == CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE and city_gdp_derivative_world_bridge.has_method("bind_world") and city_gdp_derivative_world_bridge.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the non-owning CityGdpDerivativeRuntimeWorldBridge scene")
	_expect(hand_interaction != null and hand_interaction.scene_file_path == "res://scenes/runtime/PlayerHandInteractionRuntimeService.tscn" and hand_interaction.has_method("plan_interaction") and hand_interaction.has_method("commit_interaction") and hand_interaction.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable PlayerHandInteractionRuntimeService scene and orchestration/cash/event-intent API")
	_expect(purchase_settlement != null and purchase_settlement.scene_file_path == "res://scenes/runtime/DistrictPurchaseSettlementRuntimeService.tscn" and purchase_settlement.has_method("plan_purchase") and purchase_settlement.has_method("commit_purchase") and purchase_settlement.has_method("validate_discard"), "GameRuntimeCoordinator owns the editable DistrictPurchaseSettlementRuntimeService scene")
	_expect(district_supply_snapshot != null and district_supply_snapshot.scene_file_path == "res://scenes/runtime/DistrictSupplySnapshotService.tscn" and district_supply_snapshot.has_method("compose") and district_supply_snapshot.has_method("validate_source") and district_supply_snapshot.has_method("debug_snapshot"), "GameRuntimeCoordinator owns the editable DistrictSupplySnapshotService scene")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for retired_diagnostic in ["_development_route_profiles", "_card_strength_budget_report", "_development_route_balance_audit", "_development_route_pressure_audit", "_direct_interaction_balance_report", "_role_balance_audit", "_monster_ecology_balance_report", "_product_ecosystem_report", "_card_supply_product_filter_audit", "_card_one_glance_audit_report", "_runtime_balance_snapshot"]:
		_expect(not main_source.contains("func %s(" % retired_diagnostic), "Sprint 62 deletes legacy main.gd diagnostic owner %s" % retired_diagnostic)
	var buy_start := main_source.find("func _buy_card_for_player_from_district(")
	var buy_end := main_source.find("\nfunc ", buy_start + 5)
	var buy_source := main_source.substr(buy_start, buy_end - buy_start) if buy_start >= 0 and buy_end > buy_start else ""
	_expect(main_source.contains("func _buy_card_for_player_from_district(") and main_source.contains("func _acquire_card_for_player(") and main_source.contains("func _acquire_inventory_skill_for_player(") and buy_source.contains("plan_district_purchase_settlement") and buy_source.contains("commit_district_purchase_settlement") and main_source.contains("plan_card_inventory_receive") and main_source.contains("commit_card_inventory_receive") and not buy_source.contains("player[\"cash\"] =") and not buy_source.contains("_record_player_card_spend(") and not main_source.contains("func _record_player_card_purchase(") and not main_source.contains("func _discard_card_from_player("), "Sprint 31 keeps thin purchase and receive adapters while later interaction slot mutations route through scene services")
	_expect(main_source.contains("func _apply_player_hand_disrupt(") and main_source.contains("func _apply_player_hand_steal(") and main_source.contains("func _resolve_player_hand_interaction(") and not main_source.contains("func _take_private_hand_card_from_player(") and not main_source.contains("func _lock_private_hand_card_for_player(") and not main_source.contains("func _transfer_private_hand_card_between_players("), "Sprint 33 keeps compatibility entry points while deleting the three legacy interaction mutation helpers")
	var disrupt_source := _function_source(main_source, "_apply_player_hand_disrupt")
	var steal_source := _function_source(main_source, "_apply_player_hand_steal")
	var interaction_adapter_source := _function_source(main_source, "_resolve_player_hand_interaction")
	var interaction_service_source := FileAccess.get_file_as_string("res://scripts/runtime/player_hand_interaction_runtime_service.gd")
	_expect(disrupt_source.contains("_resolve_player_hand_interaction") and steal_source.contains("_resolve_player_hand_interaction") and interaction_adapter_source.contains("plan_player_hand_interaction") and interaction_adapter_source.contains("commit_player_hand_interaction") and not disrupt_source.contains("target_cash_penalty") and not steal_source.contains("steal_fail_cash") and interaction_service_source.contains("_inventory_service.call(\"commit_remove\"") and interaction_service_source.contains("_inventory_service.call(\"commit_lock\"") and interaction_service_source.contains("_inventory_service.call(\"commit_transfer\""), "Player-hand interaction entry points are thin and the scene service delegates all slot mutation to CardInventoryRuntimeService")
	var queue_submit_source := _function_source(main_source, "_queue_skill_resolution")
	var queue_lock_source := _function_source(main_source, "_lock_card_resolution_batch")
	var queue_start_source := _function_source(main_source, "_start_next_card_resolution")
	var queue_promote_source := _function_source(main_source, "_promote_next_card_resolution_batch")
	_expect(not main_source.contains("var card_resolution_queue := []") and not main_source.contains("var next_card_resolution_queue := []") and not main_source.contains("var active_card_resolution := {}") and not main_source.contains("var card_resolution_sequence := 0") and queue_submit_source.contains("plan_card_resolution_queue_submission") and queue_submit_source.contains("commit_card_inventory_queue_commit") and queue_submit_source.contains("commit_card_resolution_queue_submission") and queue_lock_source.contains("service.call(\"lock_batch\"") and queue_start_source.contains("service.call(\"start_next\"") and queue_promote_source.contains("service.call(\"promote_next_batch\""), "Sprint 35 deletes main.gd queue storage and routes queue lifecycle through the single scene service")
	var execution_complete_source := _function_source(main_source, "_complete_active_card_resolution")
	var execution_effect_adapter_source := _function_source(main_source, "_apply_card_resolution_effect_request")
	var execution_service_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_runtime_service.gd")
	var family_service_source := FileAccess.get_file_as_string("res://scripts/runtime/card_economy_product_route_effect_runtime_service.gd")
	var family_bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/card_economy_product_route_effect_world_bridge.gd")
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
	_expect(execution_complete_source.contains("plan_card_resolution_execution") and execution_complete_source.contains("advance_card_resolution_execution") and execution_complete_source.contains("finalize_card_resolution_execution") and execution_effect_adapter_source.contains("_resolve_targeted_skill") and execution_effect_adapter_source.contains("_apply_player_hand_disrupt") and execution_service_source.contains("INTENT_RELEASE_ACTIVE") and execution_service_source.contains("INTENT_DISPATCH_EFFECT"), "Sprint 37 routes lifecycle through Execution Service while main retains concrete world adapters")
	var family_methods := ["_apply_route_insurance", "_apply_region_economy_shift"]
	var family_cutover_checked := execution_effect_adapter_source.contains("plan_card_economy_product_route_effect") and execution_effect_adapter_source.contains("finalize_card_economy_product_route_effect") and family_service_source.contains("HANDLER_FAMILIES")
	for method_name in family_methods:
		family_cutover_checked = family_cutover_checked and not execution_effect_adapter_source.contains(method_name) and family_bridge_source.contains(method_name) and not execution_service_source.contains(method_name)
	family_cutover_checked = family_cutover_checked and family_bridge_source.contains("_product_market_runtime_controller.apply_speculation") and family_bridge_source.contains("_product_market_runtime_controller.apply_futures") and not execution_service_source.contains("apply_speculation")
	family_cutover_checked = family_cutover_checked and family_bridge_source.contains("contract_controller.open_offer") and not main_source.contains("func _apply_area_trade_contract(")
	_expect(family_cutover_checked, "Sprint 40 preserves modular economy/product/route dispatch and keeps Execution Service family-agnostic")
	var product_market_source := FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd")
	var market_boon_source := _function_source(product_market_source, "apply_product_market_boon")
	var futures_settlement_source := _function_source(product_market_source, "settle_futures_position")
	var city_trade_network_source := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCRIPT)
	var route_flow_source := _function_source(city_trade_network_source, "_trade_route_for_product")
	var product_contract_source := _function_source(product_market_source, "apply_product_contract_boon")
	var city_contract_source := _function_source(main_source, "_apply_city_contract_boon")
	var route_insurance_source := _function_source(main_source, "_apply_route_insurance")
	var city_upgrade_source := _function_source(main_source, "_apply_city_product_upgrade")
	var product_shift_source := _function_source(main_source, "_apply_city_product_shift")
	var demand_shift_source := _function_source(main_source, "_apply_city_demand_shift")
	var formula_cutover_checked := formula_service_source.contains("FORMULA_IDS") and formula_service_source.contains("func _product_contract_boon(") and formula_service_source.contains("func _city_contract_boon(") and formula_service_source.contains("func _route_insurance(") and formula_service_source.contains("product_futures_v04_settlement") and formula_service_source.contains("warehouse_futures_v04_loss") and not formula_service_source.contains("\"product_futures_payout\"") and market_boon_source.contains("_formula(\"product_market_boon\"") and not market_boon_source.contains("clampf(") and futures_settlement_source.contains("settlement_formula_id") and not futures_settlement_source.contains("paying_delta") and route_flow_source.contains("route_base_flow") and not route_flow_source.contains("sqrt(") and product_contract_source.contains("product_contract_boon") and not product_contract_source.contains("market_contract_demand\"] = maxi") and city_contract_source.contains("city_contract_boon") and not city_contract_source.contains("contract_income_bonus\"] = maxi") and route_insurance_source.contains("route_insurance") and city_upgrade_source.contains("city_product_upgrade") and product_shift_source.contains("city_product_shift_step") and demand_shift_source.contains("city_demand_shift_step") and not main_source.contains("func _lowest_level_city_product_index(") and not main_source.contains("func _product_futures_balance_") and not main_source.contains("PRODUCT_FUTURES_PAYOUT_UNIT") and not execution_service_source.contains("CardEconomyProductRouteFormulaRuntimeService") and not execution_service_source.contains("city_product_upgrade")
	_expect(formula_cutover_checked, "Sprint 40 removes both characterized pure formula clusters from main while Execution Service remains formula-agnostic")
	_expect(economy != null and economy.scene_file_path == "res://scenes/runtime/EconomyCashflowRuntimeController.tscn" and economy.has_method("advance_clock") and economy.has_method("settle_sources") and economy.has_method("to_legacy_save_snapshot"), "GameRuntimeCoordinator owns the editable EconomyCashflowRuntimeController scene")
	_expect(gdp_formula != null and gdp_formula.scene_file_path == "res://scenes/runtime/GdpFormulaRuntimeController.tscn" and gdp_formula.has_method("calculate_city_gdp") and gdp_formula.has_method("parameters_snapshot") and gdp_formula.has_method("breakdown_summary"), "GameRuntimeCoordinator owns the editable GdpFormulaRuntimeController scene")
	_expect(scenario != null and scenario.scene_file_path == "res://scenes/runtime/ScenarioRuntimeController.tscn" and scenario.has_method("start_scenario") and scenario.has_method("complete_signal") and scenario.has_method("viewer_action_log"), "GameRuntimeCoordinator owns the editable ScenarioRuntimeController scene")
	_expect(first_table_authored != null and first_table_authored.scene_file_path == "res://scenes/runtime/FirstTableAuthoredRuntimeService.tscn" and first_table_authored.has_method("resolve_content_catalog") and first_table_authored.has_method("compose_runtime_content") and first_table_authored.has_method("contextualize_phase") and first_table_authored.has_method("pacing_profile") and first_table_authored.has_method("evaluate_pacing") and first_table_authored.has_method("supply_plan"), "GameRuntimeCoordinator owns the editable FirstTableAuthoredRuntimeService scene and its authored pacing API")
	_expect(codex_navigation != null and codex_navigation.scene_file_path == "res://scenes/runtime/CodexNavigationRuntimeController.tscn" and codex_navigation.has_method("navigation_snapshot") and codex_navigation.has_method("to_legacy_save_snapshot") and codex_navigation.has_method("apply_legacy_save_snapshot"), "GameRuntimeCoordinator owns the editable CodexNavigationRuntimeController scene")
	_expect(codex_public_snapshot != null and codex_public_snapshot.scene_file_path == "res://scenes/runtime/CodexPublicSnapshotService.tscn" and codex_public_snapshot.has_method("compose_role") and codex_public_snapshot.has_method("compose_region"), "GameRuntimeCoordinator owns the editable CodexPublicSnapshotService scene")
	_expect(monster_codex_public_snapshot != null and monster_codex_public_snapshot.scene_file_path == "res://scenes/runtime/MonsterCodexPublicSnapshotService.tscn" and monster_codex_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable MonsterCodexPublicSnapshotService scene")
	_expect(product_codex_public_snapshot != null and product_codex_public_snapshot.scene_file_path == "res://scenes/runtime/ProductCodexPublicSnapshotService.tscn" and product_codex_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable ProductCodexPublicSnapshotService scene")
	_expect(card_codex_public_snapshot != null and card_codex_public_snapshot.scene_file_path == "res://scenes/runtime/CardCodexPublicSnapshotService.tscn" and card_codex_public_snapshot.has_method("compose_browser") and card_codex_public_snapshot.has_method("compose_detail"), "GameRuntimeCoordinator owns the editable CardCodexPublicSnapshotService scene")
	_expect(economy_dashboard_public_snapshot != null and economy_dashboard_public_snapshot.scene_file_path == "res://scenes/runtime/EconomyDashboardPublicSnapshotService.tscn" and economy_dashboard_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable EconomyDashboardPublicSnapshotService scene")
	_expect(standings_public_snapshot != null and standings_public_snapshot.scene_file_path == "res://scenes/runtime/StandingsPublicSnapshotService.tscn" and standings_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable StandingsPublicSnapshotService scene")
	_expect(final_settlement_public_snapshot != null and final_settlement_public_snapshot.scene_file_path == "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn" and final_settlement_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable FinalSettlementPublicSnapshotService scene")
	_expect(intel_dossier_public_snapshot != null and intel_dossier_public_snapshot.scene_file_path == "res://scenes/runtime/IntelDossierPublicSnapshotService.tscn" and intel_dossier_public_snapshot.has_method("compose"), "GameRuntimeCoordinator owns the editable IntelDossierPublicSnapshotService scene")
	var audio_host := main.get_node_or_null("RuntimeServices/TableAudioHost")
	for player_name in ["NightPatrolTableBgm", "NightPatrolSfx_card", "NightPatrolSfx_impact", "NightPatrolSfx_storm"]:
		_expect(audio_host != null and audio_host.get_node_or_null(player_name) is AudioStreamPlayer, "TableAudioHost owns %s" % player_name)


func _check_runtime_snapshot(main: Control, phase: String) -> void:
	_expect(main.has_method("_runtime_composition_snapshot"), "main.gd exposes runtime composition snapshot")
	if not main.has_method("_runtime_composition_snapshot"):
		return
	var snapshot: Dictionary = main.call("_runtime_composition_snapshot")
	_expect(_is_pure_data(snapshot), "%s snapshot contains pure data only" % phase)
	_expect(bool(snapshot.get("sceneized_composition_enabled", false)), "%s keeps sceneized composition enabled" % phase)
	_expect(not bool(snapshot.get("legacy_fallback_used", true)), "%s does not use compatibility fallback creation" % phase)
	_expect(not snapshot.has("legacy_table_shell_found"), "%s no longer exposes a retired legacy shell field" % phase)
	_expect(bool(snapshot.get("card_resolution_controller_found", false)), "%s finds CardResolutionRuntimeController" % phase)
	_expect(bool(snapshot.get("city_development_controller_found", false)), "%s finds CityDevelopmentRuntimeController" % phase)
	_expect(bool(snapshot.get("city_development_controller_ready", false)) and bool(snapshot.get("city_development_controller_bound", false)) and bool(snapshot.get("city_development_controller_authoritative", false)), "%s binds the v0.4 CityDevelopmentRuntimeController" % phase)
	_expect(bool(snapshot.get("game_runtime_coordinator_found", false)) and bool(snapshot.get("forced_decision_scheduler_found", false)), "%s finds GameRuntimeCoordinator and ForcedDecisionRuntimeScheduler" % phase)
	_expect(bool(snapshot.get("gdp_formula_runtime_controller_found", false)), "%s finds GdpFormulaRuntimeController" % phase)
	_expect(bool(snapshot.get("first_table_authored_runtime_service_found", false)), "%s finds FirstTableAuthoredRuntimeService" % phase)
	_expect(bool(snapshot.get("codex_navigation_runtime_controller_found", false)), "%s finds CodexNavigationRuntimeController" % phase)
	_expect(bool(snapshot.get("codex_public_snapshot_service_found", false)), "%s finds CodexPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("monster_codex_public_snapshot_service_found", false)), "%s finds MonsterCodexPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("product_codex_public_snapshot_service_found", false)), "%s finds ProductCodexPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("card_codex_public_snapshot_service_found", false)), "%s finds CardCodexPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("economy_dashboard_public_snapshot_service_found", false)), "%s finds EconomyDashboardPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("standings_public_snapshot_service_found", false)), "%s finds StandingsPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("final_settlement_public_snapshot_service_found", false)), "%s finds FinalSettlementPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("intel_dossier_public_snapshot_service_found", false)), "%s finds IntelDossierPublicSnapshotService" % phase)
	_expect(bool(snapshot.get("game_session_runtime_controller_found", false)) and bool(snapshot.get("game_save_runtime_coordinator_found", false)), "%s finds GameSessionRuntimeController and GameSaveRuntimeCoordinator" % phase)
	_expect(bool(snapshot.get("game_runtime_coordinator_ready", false)) and bool(snapshot.get("game_runtime_coordinator_bound", false)) and bool(snapshot.get("game_runtime_coordinator_authoritative", false)), "%s binds the v0.4 GameRuntimeCoordinator" % phase)
	var coordinator_snapshot: Dictionary = snapshot.get("game_runtime_coordinator", {}) if snapshot.get("game_runtime_coordinator", {}) is Dictionary else {}
	var scheduler_snapshot: Dictionary = coordinator_snapshot.get("forced_decision_scheduler", {}) if coordinator_snapshot.get("forced_decision_scheduler", {}) is Dictionary else {}
	var session_snapshot: Dictionary = coordinator_snapshot.get("game_session", {}) if coordinator_snapshot.get("game_session", {}) is Dictionary else {}
	var purchase_snapshot: Dictionary = coordinator_snapshot.get("district_purchase", {}) if coordinator_snapshot.get("district_purchase", {}) is Dictionary else {}
	var card_inventory_snapshot: Dictionary = coordinator_snapshot.get("card_inventory", {}) if coordinator_snapshot.get("card_inventory", {}) is Dictionary else {}
	var card_resolution_queue_snapshot: Dictionary = coordinator_snapshot.get("card_resolution_queue", {}) if coordinator_snapshot.get("card_resolution_queue", {}) is Dictionary else {}
	var effect_formula_snapshot: Dictionary = coordinator_snapshot.get("card_economy_product_route_formula", {}) if coordinator_snapshot.get("card_economy_product_route_formula", {}) is Dictionary else {}
	var purchase_settlement_snapshot: Dictionary = coordinator_snapshot.get("district_purchase_settlement", {}) if coordinator_snapshot.get("district_purchase_settlement", {}) is Dictionary else {}
	var district_supply_snapshot: Dictionary = coordinator_snapshot.get("district_supply_snapshot", {}) if coordinator_snapshot.get("district_supply_snapshot", {}) is Dictionary else {}
	var economy_snapshot: Dictionary = coordinator_snapshot.get("economy_cashflow", {}) if coordinator_snapshot.get("economy_cashflow", {}) is Dictionary else {}
	var scenario_snapshot: Dictionary = coordinator_snapshot.get("scenario_runtime", {}) if coordinator_snapshot.get("scenario_runtime", {}) is Dictionary else {}
	var first_table_snapshot: Dictionary = coordinator_snapshot.get("first_table_authored_runtime", {}) if coordinator_snapshot.get("first_table_authored_runtime", {}) is Dictionary else {}
	var codex_navigation_snapshot: Dictionary = coordinator_snapshot.get("codex_navigation_runtime", {}) if coordinator_snapshot.get("codex_navigation_runtime", {}) is Dictionary else {}
	var codex_public_snapshot: Dictionary = coordinator_snapshot.get("codex_public_snapshot", {}) if coordinator_snapshot.get("codex_public_snapshot", {}) is Dictionary else {}
	var monster_codex_public_snapshot: Dictionary = coordinator_snapshot.get("monster_codex_public_snapshot", {}) if coordinator_snapshot.get("monster_codex_public_snapshot", {}) is Dictionary else {}
	var product_codex_public_snapshot: Dictionary = coordinator_snapshot.get("product_codex_public_snapshot", {}) if coordinator_snapshot.get("product_codex_public_snapshot", {}) is Dictionary else {}
	var card_codex_public_snapshot: Dictionary = coordinator_snapshot.get("card_codex_public_snapshot", {}) if coordinator_snapshot.get("card_codex_public_snapshot", {}) is Dictionary else {}
	var economy_dashboard_public_snapshot: Dictionary = coordinator_snapshot.get("economy_dashboard_public_snapshot", {}) if coordinator_snapshot.get("economy_dashboard_public_snapshot", {}) is Dictionary else {}
	var standings_public_snapshot: Dictionary = coordinator_snapshot.get("standings_public_snapshot", {}) if coordinator_snapshot.get("standings_public_snapshot", {}) is Dictionary else {}
	var final_settlement_public_snapshot: Dictionary = coordinator_snapshot.get("final_settlement_public_snapshot", {}) if coordinator_snapshot.get("final_settlement_public_snapshot", {}) is Dictionary else {}
	var intel_dossier_public_snapshot: Dictionary = coordinator_snapshot.get("intel_dossier_public_snapshot", {}) if coordinator_snapshot.get("intel_dossier_public_snapshot", {}) is Dictionary else {}
	var card_presentation_snapshot: Dictionary = coordinator_snapshot.get("card_presentation", {}) if coordinator_snapshot.get("card_presentation", {}) is Dictionary else {}
	var table_viewmodel_snapshot: Dictionary = coordinator_snapshot.get("game_table_viewmodel", {}) if coordinator_snapshot.get("game_table_viewmodel", {}) is Dictionary else {}
	_expect(scheduler_snapshot.get("priority_order", []) == ["monster_wager", "counter_response", "contract_response", "other_choice"], "%s configures forced-decision priority from RulesetRuntimeBridge" % phase)
	_expect(bool(session_snapshot.get("session_ready", false)) and bool(session_snapshot.get("session_authoritative", false)), "%s configures scene-owned session/save authority" % phase)
	_expect(bool(purchase_snapshot.get("controller_ready", false)) and bool(purchase_snapshot.get("controller_authoritative", false)) and is_equal_approx(float(purchase_snapshot.get("purchase_window_seconds", 0.0)), 12.0), "%s configures the scene-owned v0.4 district purchase authority" % phase)
	_expect(bool(card_inventory_snapshot.get("service_ready", false)) and bool(card_inventory_snapshot.get("service_authoritative", false)) and int(card_inventory_snapshot.get("ordinary_hand_limit", 0)) == 5 and int(card_inventory_snapshot.get("maximum_card_rank", 0)) == 4 and not bool(card_inventory_snapshot.get("purchase_cash_authority", true)) and not bool(card_inventory_snapshot.get("ledger_authority", true)) and not bool(card_inventory_snapshot.get("legacy_inventory_fallback_used", true)), "%s configures CardInventoryRuntimeService as the v0.4 slot-mutation authority without moving cash or ledger ownership" % phase)
	_expect(bool(snapshot.get("card_resolution_queue_runtime_service_found", false)) and bool(card_resolution_queue_snapshot.get("service_ready", false)) and bool(card_resolution_queue_snapshot.get("service_authoritative", false)) and not bool(card_resolution_queue_snapshot.get("timing_authority", true)) and not bool(card_resolution_queue_snapshot.get("card_effect_authority", true)) and not bool(card_resolution_queue_snapshot.get("inventory_authority", true)) and not bool(card_resolution_queue_snapshot.get("legacy_queue_fallback_used", true)), "%s configures CardResolutionQueueRuntimeService as the v0.4 queue-lifecycle authority without moving timing, effects, or inventory ownership" % phase)
	_expect(bool(effect_formula_snapshot.get("service_ready", false)) and bool(effect_formula_snapshot.get("pure_formula_authority", false)) and not bool(effect_formula_snapshot.get("effect_dispatch_authority", true)) and not bool(effect_formula_snapshot.get("world_mutation_authority", true)) and not bool(effect_formula_snapshot.get("execution_lifecycle_authority", true)), "%s configures the pure Formula Service without expanding execution or world ownership" % phase)
	_expect(bool(purchase_settlement_snapshot.get("service_ready", false)) and bool(purchase_settlement_snapshot.get("service_authoritative", false)) and not bool(purchase_settlement_snapshot.get("window_authority", true)) and not bool(purchase_settlement_snapshot.get("presentation_authority", true)) and not bool(purchase_settlement_snapshot.get("legacy_settlement_fallback_used", true)), "%s configures the scene-owned atomic District Purchase Settlement service without moving window or presentation authority" % phase)
	_expect(bool(district_supply_snapshot.get("service_ready", false)) and bool(district_supply_snapshot.get("service_authoritative", false)) and not bool(district_supply_snapshot.get("calculates_purchase_eligibility", true)) and not bool(district_supply_snapshot.get("calculates_card_price", true)) and not bool(district_supply_snapshot.get("mutates_inventory", true)), "%s configures the scene-owned District Supply presentation formatter without moving purchase rules" % phase)
	_expect(bool(snapshot.get("economy_cashflow_runtime_controller_found", false)) and bool(economy_snapshot.get("controller_ready", false)) and bool(economy_snapshot.get("controller_authoritative", false)), "%s finds and configures the scene-owned economy cashflow authority" % phase)
	_expect(is_equal_approx(float(economy_snapshot.get("tick_interval_seconds", 0.0)), 1.0) and is_equal_approx(float(economy_snapshot.get("basis_seconds", 0.0)), 60.0), "%s preserves the one-second cadence and sixty-second GDP basis" % phase)
	_expect(bool(snapshot.get("scenario_runtime_controller_found", false)) and bool(scenario_snapshot.get("controller_ready", false)) and bool(scenario_snapshot.get("controller_authoritative", false)), "%s finds and configures the scene-owned scenario runtime authority" % phase)
	_expect(bool(first_table_snapshot.get("service_ready", false)) and bool(first_table_snapshot.get("service_authoritative", false)) and not bool(first_table_snapshot.get("legacy_authored_fallback_used", true)), "%s configures scene-owned first_table authored runtime authority" % phase)
	_expect(bool(codex_navigation_snapshot.get("controller_ready", false)) and bool(codex_navigation_snapshot.get("controller_authoritative", false)) and not bool(codex_navigation_snapshot.get("legacy_main_authority_active", true)), "%s configures scene-owned Codex navigation authority" % phase)
	_expect(bool(codex_public_snapshot.get("service_ready", false)) and bool(codex_public_snapshot.get("service_authoritative", false)) and not bool(codex_public_snapshot.get("legacy_main_formatter_active", true)), "%s configures scene-owned Role/Region public snapshot authority" % phase)
	_expect(bool(monster_codex_public_snapshot.get("service_ready", false)) and bool(monster_codex_public_snapshot.get("service_authoritative", false)) and not bool(monster_codex_public_snapshot.get("calculates_action_weights", true)), "%s configures scene-owned Monster public snapshot authority without moving probability algorithms" % phase)
	_expect(bool(product_codex_public_snapshot.get("service_ready", false)) and bool(product_codex_public_snapshot.get("service_authoritative", false)) and not bool(product_codex_public_snapshot.get("calculates_market_price", true)) and not bool(product_codex_public_snapshot.get("calculates_strategy_scores", true)), "%s configures scene-owned Product public snapshot authority without moving market or strategy algorithms" % phase)
	_expect(bool(card_codex_public_snapshot.get("service_ready", false)) and bool(card_codex_public_snapshot.get("service_authoritative", false)) and bool(card_codex_public_snapshot.get("uses_existing_browser_viewmodel", false)) and bool(card_codex_public_snapshot.get("uses_existing_detail_viewmodel", false)) and not bool(card_codex_public_snapshot.get("calculates_card_price", true)) and not bool(card_codex_public_snapshot.get("calculates_card_effects", true)) and not bool(card_codex_public_snapshot.get("calculates_play_requirements", true)), "%s configures scene-owned Card public snapshot authority while preserving rule ownership" % phase)
	_expect(bool(economy_dashboard_public_snapshot.get("service_ready", false)) and bool(economy_dashboard_public_snapshot.get("service_authoritative", false)) and not bool(economy_dashboard_public_snapshot.get("calculates_product_prices", true)) and not bool(economy_dashboard_public_snapshot.get("calculates_city_income", true)) and not bool(economy_dashboard_public_snapshot.get("calculates_cashflow", true)) and not bool(economy_dashboard_public_snapshot.get("evaluates_private_truth", true)), "%s configures scene-owned Economy Dashboard presentation without moving economy rules" % phase)
	_expect(bool(standings_public_snapshot.get("service_ready", false)) and bool(standings_public_snapshot.get("service_authoritative", false)) and not bool(standings_public_snapshot.get("calculates_settlement_score", true)) and not bool(standings_public_snapshot.get("calculates_city_income", true)) and not bool(standings_public_snapshot.get("sorts_final_rankings", true)) and not bool(standings_public_snapshot.get("evaluates_private_truth", true)), "%s configures scene-owned Standings presentation without moving scoring or economy rules" % phase)
	_expect(bool(final_settlement_public_snapshot.get("service_ready", false)) and bool(final_settlement_public_snapshot.get("service_authoritative", false)) and not bool(final_settlement_public_snapshot.get("calculates_final_score", true)) and not bool(final_settlement_public_snapshot.get("sorts_final_rankings", true)) and not bool(final_settlement_public_snapshot.get("calculates_city_clearance", true)) and not bool(final_settlement_public_snapshot.get("calculates_intel_cash", true)) and not bool(final_settlement_public_snapshot.get("reads_private_hands", true)), "%s configures scene-owned Final Settlement presentation without moving scoring or private history" % phase)
	_expect(bool(intel_dossier_public_snapshot.get("service_ready", false)) and bool(intel_dossier_public_snapshot.get("service_authoritative", false)) and not bool(intel_dossier_public_snapshot.get("mutates_city_guesses", true)) and not bool(intel_dossier_public_snapshot.get("settles_intel_cash", true)) and not bool(intel_dossier_public_snapshot.get("reveals_city_owner_truth", true)) and not bool(intel_dossier_public_snapshot.get("reveals_card_owner_truth", true)) and not bool(intel_dossier_public_snapshot.get("reads_private_hands", true)) and bool(intel_dossier_public_snapshot.get("action_id_controls", false)), "%s configures scene-owned Intel Dossier presentation and action intents without moving hidden truth or settlement" % phase)
	_expect(bool(card_presentation_snapshot.get("service_ready", false)) and bool(card_presentation_snapshot.get("service_authoritative", false)) and bool(card_presentation_snapshot.get("owns_card_use_case", false)) and bool(card_presentation_snapshot.get("owns_hand_card_viewmodel", false)) and not bool(card_presentation_snapshot.get("calculates_card_price", true)) and not bool(card_presentation_snapshot.get("calculates_play_legality", true)) and not bool(card_presentation_snapshot.get("mutates_game_state", true)), "%s configures scene-owned card presentation without moving price, legality, or mutation rules" % phase)
	_expect(bool(table_viewmodel_snapshot.get("service_ready", false)) and bool(table_viewmodel_snapshot.get("service_authoritative", false)) and bool(table_viewmodel_snapshot.get("owns_table_snapshot_normalization", false)) and bool(table_viewmodel_snapshot.get("owns_right_inspector_assembly", false)) and bool(table_viewmodel_snapshot.get("owns_public_track_viewmodels", false)) and bool(table_viewmodel_snapshot.get("owns_resolution_overlay_badges", false)) and not bool(table_viewmodel_snapshot.get("calculates_play_legality", true)) and not bool(table_viewmodel_snapshot.get("mutates_game_state", true)), "%s configures scene-owned TableSnapshot, public track, resolution-overlay badge, and RightInspector assembly" % phase)
	_expect(bool(card_presentation_snapshot.get("owns_resolution_presentation", false)), "%s configures scene-owned card-resolution cinematic presentation" % phase)
	var save_snapshot: Dictionary = session_snapshot.get("save_operation", {}) if session_snapshot.get("save_operation", {}) is Dictionary else {}
	_expect(int(save_snapshot.get("save_version", 0)) == 1 and str(save_snapshot.get("default_save_path", "")) == "user://space_syndicate_current_run.save", "%s preserves current-run save version and default path" % phase)
	var city_snapshot: Dictionary = snapshot.get("city_development_runtime", {}) if snapshot.get("city_development_runtime", {}) is Dictionary else {}
	_expect(not bool(city_snapshot.get("direct_build_allowed", true)) and bool(city_snapshot.get("project_binding_required", false)), "%s enforces product-bound development and rejects direct building" % phase)
	_expect(bool(snapshot.get("ruleset_runtime_bridge_found", false)), "%s finds RulesetRuntimeBridge" % phase)
	_expect(bool(snapshot.get("ruleset_bridge_ready", false)) and bool(snapshot.get("ruleset_bridge_bound", false)), "%s binds the v0.4 RulesetRuntimeBridge" % phase)
	_expect(str(snapshot.get("ruleset_id", "")) == "v0.4", "%s reports ruleset v0.4" % phase)
	var ruleset_snapshot: Dictionary = snapshot.get("ruleset_runtime", {}) if snapshot.get("ruleset_runtime", {}) is Dictionary else {}
	var timing: Dictionary = ruleset_snapshot.get("timing", {}) if ruleset_snapshot.get("timing", {}) is Dictionary else {}
	_expect(is_equal_approx(float(timing.get("final_countdown_seconds", 0.0)), 75.0), "%s exposes the 75-second final countdown" % phase)
	_expect(is_equal_approx(float(timing.get("monster_wager_default_seconds", 0.0)), 20.0) and is_equal_approx(float(timing.get("monster_wager_max_seconds", 0.0)), 30.0), "%s exposes the 20/30-second monster wager rule" % phase)
	_expect(not bool(snapshot.get("controller_missing", true)), "%s reports the card-resolution controller as present" % phase)
	_expect(bool(snapshot.get("controller_authoritative", false)), "%s uses the scene-owned card-resolution controller as authority" % phase)
	_expect(not bool(snapshot.get("legacy_state_fallback_used", true)), "%s keeps the card-resolution legacy state fallback inactive" % phase)
	_expect(int(snapshot.get("duplicate_node_count", -1)) == 0, "%s has no duplicate composition nodes" % phase)
	_expect(int(snapshot.get("duplicate_signal_count", -1)) == 0, "%s has no duplicate GameScreen signal bindings" % phase)
	_expect((snapshot.get("missing_nodes", []) as Array).is_empty(), "%s has no missing composition nodes" % phase)


func _check_runtime_signal_bindings(main: Control) -> void:
	var screen := main.get_node_or_null("RuntimeGameScreen") as Control
	if screen == null:
		return
	var bindings := {
		"action_requested": "_on_runtime_game_screen_action_requested",
		"end_turn_requested": "_on_runtime_game_screen_end_turn_requested",
		"card_selected": "_on_runtime_game_screen_card_selected",
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


func _check_runtime_controller_authority(main: Control) -> void:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController")
	if controller == null:
		return
	_expect(is_equal_approx(float(controller.get("total_window_seconds")), 30.0) and is_equal_approx(float(controller.get("lock_seconds")), 5.0), "RulesetRuntimeBridge configures the controller's 30/25/5 window")
	_expect(is_equal_approx(float(controller.get("counter_seconds")), 5.0), "RulesetRuntimeBridge configures the controller response window")
	main.set("card_resolution_simultaneous_timer", 12.0)
	_expect(is_equal_approx(float(controller.get("simultaneous_timer")), 12.0), "main compatibility property writes into the scene-owned controller")
	controller.set("simultaneous_timer", 9.0)
	_expect(is_equal_approx(float(main.get("card_resolution_simultaneous_timer")), 9.0), "main compatibility property reads from the scene-owned controller authority")
	main.set("card_resolution_auction_timer", 4.0)
	main.set("card_resolution_auction_open", true)
	main.set("card_group_window_sequence", 12)
	var saved: Dictionary = main.call("_capture_run_state")
	_expect(is_equal_approx(float(saved.get("card_resolution_simultaneous_timer", 0.0)), 9.0) and int(saved.get("card_group_window_sequence", 0)) == 12, "main save capture preserves controller-owned state under existing keys")
	var legacy_lock_state := saved.duplicate(true)
	legacy_lock_state["card_resolution_simultaneous_timer"] = 0.0
	legacy_lock_state["card_resolution_auction_timer"] = 4.0
	legacy_lock_state["card_resolution_auction_open"] = true
	var apply_error := int(main.call("_apply_run_state", legacy_lock_state))
	_expect(apply_error == OK and is_equal_approx(float(controller.get("simultaneous_timer")), 4.0), "main save apply preserves legacy auction-only mapping through the controller bridge")
	if controller.has_method("reset_state"):
		controller.call("reset_state")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var purchase := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/DistrictPurchaseRuntimeController")
	_expect(coordinator != null and purchase != null, "district purchase controller is available for runtime authority checks")
	if coordinator != null and purchase != null:
		purchase.call("reset_state")
		var purchase_window: Dictionary = coordinator.call("open_district_purchase_window", 0, 2, {"eligible": true, "access_kind": "landed", "opened_at": 3.0, "source_kind": "monster", "source_bound_to_player": true, "channel_discount_multiplier": 0.8, "supply_revision": "composition-a"})
		_expect(is_equal_approx(float(purchase_window.get("remaining_seconds", 0.0)), 12.0) and is_equal_approx(float(purchase_window.get("locked_price_multiplier", 0.0)), 0.64), "district purchase authority locks the v0.4 duration and private channel price context")
		var captured: Dictionary = main.call("_capture_run_state")
		var legacy_purchase: Dictionary = captured.get("district_card_purchase_snapshot", {}) if captured.get("district_card_purchase_snapshot", {}) is Dictionary else {}
		_expect(int(legacy_purchase.get("district_index", -1)) == 2 and is_equal_approx(float(legacy_purchase.get("remaining_seconds", 0.0)), 12.0), "existing v1 save key is composed from controller-owned state")
		coordinator.call("tick_district_purchase_windows", 12.0, [])
		_expect(not bool(coordinator.call("district_purchase_window_active", 0, 2)) and str((coordinator.call("district_purchase_window", 0) as Dictionary).get("state", "")) == "expired", "district purchase authority expires at exactly twelve seconds")
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
	_expect(weather_characterization_ready and weather_contract.contains("Sprint 49 status") and weather_contract.contains("Deleted legacy owner"), "Sprint 49 composes one authoritative WeatherRuntimeController and non-owning bridge while deleting the legacy main.gd weather engine")
	var contract_contract := FileAccess.get_file_as_string(CONTRACT_RUNTIME_OWNERSHIP_CONTRACT)
	var contract_characterization_ready := ResourceLoader.exists(CONTRACT_RUNTIME_CHARACTERIZATION_BENCH) and ResourceLoader.exists(CONTRACT_RUNTIME_CHARACTERIZATION_SCRIPT) and ResourceLoader.exists(CONTRACT_RUNTIME_CONTROLLER) and ResourceLoader.exists(CONTRACT_RUNTIME_WORLD_BRIDGE) and not contract_contract.is_empty()
	var contract_packed := load(CONTRACT_RUNTIME_CHARACTERIZATION_BENCH) as PackedScene
	if contract_packed != null:
		var contract_bench := contract_packed.instantiate()
		var contract_manifest: Dictionary = contract_bench.call("build_characterization_manifest_preview") if contract_bench != null and contract_bench.has_method("build_characterization_manifest_preview") else {}
		contract_characterization_ready = contract_characterization_ready and int(contract_manifest.get("case_count", 0)) == 62 and str(contract_manifest.get("runtime_owner", "")) == "res://scripts/runtime/contract_runtime_controller.gd" and bool(contract_manifest.get("runtime_cutover_enabled", false)) and _is_pure_data(contract_manifest)
		if contract_bench != null:
			contract_bench.free()
	contract_characterization_ready = contract_characterization_ready and not main_source.contains("var pending_contract_offers") and not main_source.contains("func _enqueue_pending_area_trade_contract(") and not main_source.contains("func _update_pending_contract_offers(") and not main_source.contains("func _respond_to_pending_contract_for_player(")
	contract_characterization_ready = contract_characterization_ready and coordinator_scene.count("[node name=\"ContractRuntimeController\"") == 1 and coordinator_scene.count("[node name=\"ContractRuntimeWorldBridge\"") == 1
	_expect(contract_characterization_ready and contract_contract.contains("Sprint 51 status") and contract_contract.contains("62/62") and contract_contract.contains("Deleted legacy owner"), "Sprint 51 composes one authoritative ContractRuntimeController and non-owning bridge while deleting the legacy main.gd contract engine")


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
	var ready := ResourceLoader.exists(CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH) and ResourceLoader.exists(CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_SCRIPT) and ResourceLoader.exists(CITY_TRADE_NETWORK_RUNTIME_CONTROLLER) and ResourceLoader.exists(CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCRIPT) and ResourceLoader.exists(CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE) and ResourceLoader.exists(CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCRIPT) and FileAccess.file_exists(CITY_TRADE_NETWORK_RUNTIME_OWNERSHIP_CONTRACT)
	var packed := load(CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH) as PackedScene
	var bench := packed.instantiate() if packed != null else null
	var manifest: Dictionary = bench.call("build_characterization_manifest_preview") if bench != null and bench.has_method("build_characterization_manifest_preview") else {}
	ready = ready and int(manifest.get("case_count", 0)) == 68 and str(manifest.get("runtime_owner", "")) == CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCRIPT and bool(manifest.get("runtime_cutover_enabled", false)) and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var contract := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_RUNTIME_OWNERSHIP_CONTRACT)
	var controller_source := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCRIPT)
	var bridge_source := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCRIPT)
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	ready = ready and main_source.contains("func _refresh_city_networks(") and main_source.contains("func _settle_city_cashflow_seconds(") and main_source.contains("func _city_trade_network_runtime_call(")
	ready = ready and not main_source.contains("func _shortest_trade_path(") and not main_source.contains("func _trade_path_cost(") and not main_source.contains("func _refresh_city_trade_routes(") and not main_source.contains("func _route_base_flow_amount(") and not main_source.contains("var city_product_project_sequence")
	ready = ready and controller_source.contains("func refresh_networks(") and controller_source.contains("func shortest_trade_path(") and controller_source.contains("func settle_cashflow_seconds(") and controller_source.contains("func to_save_data(") and controller_source.contains("func apply_save_data(")
	ready = ready and bridge_source.contains("func capture_world_snapshot(") and bridge_source.contains("func apply_network_receipt(") and bridge_source.contains('"owns_runtime_state": false') and bridge_source.contains('"owns_rules": false')
	ready = ready and coordinator_scene.contains("CityTradeNetworkRuntimeController") and coordinator_scene.contains("CityTradeNetworkWorldBridge") and contract.contains("Sprint 64 completed the hard cutover") and contract.contains("68/68 observed and 68/68 aligned") and contract.contains("There is no parallel route engine")
	_expect(ready, "Sprint 64 composes one CityTradeNetworkRuntimeController, a non-owning WorldBridge, and a 68-case hard-cutover gate with no parallel main.gd route engine")


func _check_city_development_settlement_characterization_assets() -> void:
	var ready := ResourceLoader.exists(CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH) and ResourceLoader.exists(CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_SCRIPT) and ResourceLoader.exists(CITY_DEVELOPMENT_RUNTIME_CONTROLLER) and ResourceLoader.exists(CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCRIPT) and ResourceLoader.exists(CITY_DEVELOPMENT_WORLD_BRIDGE) and ResourceLoader.exists(CITY_DEVELOPMENT_WORLD_BRIDGE_SCRIPT) and FileAccess.file_exists(CITY_DEVELOPMENT_SETTLEMENT_CONTRACT)
	var packed := load(CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH) as PackedScene
	var bench := packed.instantiate() if packed != null else null
	var manifest: Dictionary = bench.call("build_characterization_manifest_preview") if bench != null and bench.has_method("build_characterization_manifest_preview") else {}
	ready = ready and int(manifest.get("case_count", 0)) == 64 and bool(manifest.get("runtime_cutover_enabled", false)) and str(manifest.get("current_settlement_owner", "")) == CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCRIPT and _is_pure_data(manifest)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var contract := FileAccess.get_file_as_string(CITY_DEVELOPMENT_SETTLEMENT_CONTRACT)
	var coordinator_scene := FileAccess.get_file_as_string(GAME_RUNTIME_COORDINATOR_SCENE)
	ready = ready and coordinator_scene.count("CityDevelopmentRuntimeController") >= 1 and coordinator_scene.count("CityDevelopmentWorldBridge") >= 1
	ready = ready and not main_source.contains("func _apply_city_development_card(") and not main_source.contains("func _create_city_surface_for_development(") and not main_source.contains("PROJECT_BRIDGE.apply_development(")
	ready = ready and contract.contains("Sprint 66") and contract.contains("64/64") and contract.contains("rollback") and contract.contains("CityDevelopmentWorldBridge")
	_expect(ready, "Sprint 66 composes one authoritative CityDevelopmentRuntimeController and non-owning WorldBridge with a 64-case hard-cutover gate")


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
	ready = ready and int(schema.get("family_resources", 0)) == 120 and int(schema.get("embedded_rank_resources", 0)) == 239 and int(schema.get("pack_resources", 0)) == 10
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
	ready = ready and ownership_contract.contains("80/80") and ownership_contract.contains("CardRuntimeCatalogService") and resource_schema.contains("120 `CardRuntimeFamilyResource`") and resource_schema.contains("239 embedded `CardRuntimeRankResource`")
	_expect(ready, "Sprint 58 uses one Inspector-editable 120-family/239-rank Resource catalog, an authoritative Catalog Service, and no parallel main.gd catalog owner")


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


func _check_global_ui_navigation_characterization_assets() -> void:
	var ready := ResourceLoader.exists(GLOBAL_UI_NAVIGATION_CHARACTERIZATION_REGISTRY) and FileAccess.file_exists(GLOBAL_UI_NAVIGATION_RUNTIME_CONTRACT) and ResourceLoader.exists(MENU_SHELL_RUNTIME_CUTOVER_BENCH)
	var registry_script := load(GLOBAL_UI_NAVIGATION_CHARACTERIZATION_REGISTRY) as Script
	var registry: RefCounted = registry_script.new() if registry_script != null else null
	var cases: Array = registry.call("characterization_cases") if registry != null and registry.has_method("characterization_cases") else []
	var surfaces: Array = registry.call("surface_registry") if registry != null and registry.has_method("surface_registry") else []
	var deletion_candidates: Array = registry.call("deletion_candidates") if registry != null and registry.has_method("deletion_candidates") else []
	ready = ready and cases.size() == 32 and surfaces.size() >= 15 and deletion_candidates.size() == 8 and _is_pure_data(cases) and _is_pure_data(surfaces) and _is_pure_data(deletion_candidates)
	var bench_packed := load(MENU_SHELL_RUNTIME_CUTOVER_BENCH) as PackedScene
	var bench := bench_packed.instantiate() if bench_packed != null else null
	var preview: Dictionary = bench.call("build_global_navigation_manifest_preview") if bench != null and bench.has_method("build_global_navigation_manifest_preview") else {}
	ready = ready and bench != null and bench.has_method("global_navigation_cases") and int(preview.get("record_count", 0)) == 32 and _is_pure_data(preview)
	if bench != null:
		bench.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var input_source := _function_source(main_source, "_unhandled_input")
	ready = ready and input_source.contains("full_map_overlay") and input_source.contains("menu_overlay") and input_source.contains("_open_pause_menu()") and not input_source.contains("ui_cancel")
	ready = ready and not main_source.contains("GlobalUiNavigationRuntimeController") and not main_source.contains("func global_navigation_snapshot(")
	var contract := FileAccess.get_file_as_string(GLOBAL_UI_NAVIGATION_RUNTIME_CONTRACT)
	ready = ready and contract.contains("32/32 cases observed") and contract.contains("19/32 cases already aligned") and contract.contains("Sprint 68 deletion gate")
	_expect(ready, "Sprint 67 characterizes 32 real global navigation cases without adding a parallel runtime owner or changing main.gd behavior")


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
	ready = ready and handshake != null and handshake.has_method("inspect_envelope") and handshake.has_method("validate_v05_envelope") and handshake.has_method("compose_v05_envelope") and handshake.has_method("write_authorization")
	ready = ready and bool(handshake_snapshot.get("passive_only", false)) and not bool(handshake_snapshot.get("production_save_path_owned", true)) and _is_pure_data(handshake_snapshot)
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
	ready = ready and save_source.contains("const CURRENT_SAVE_VERSION := 1") and not save_source.contains("RulesetSaveHandshakeService")
	ready = ready and catalog_source.contains("card_runtime_catalog_v04.tres") and not catalog_source.contains("card_runtime_catalog_v05.tres")
	ready = ready and not main_source.contains("space_syndicate_ruleset_v05") and not main_source.contains("RulesetSaveHandshakeService")
	_expect(ready, "SS05-01 provides a pure-data v0.5 foundation while production ruleset, save, and card-catalog owners remain v0.4")


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
