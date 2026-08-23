extends SceneTree

const SCENE_PATHS := {
	"production_screen": "res://scenes/ui/v075/V075SampleGameScreen.tscn",
	"combat_surface": "res://scenes/ui/v075/V075CombatPlayerSurface.tscn",
	"private_skill_dock": "res://scenes/ui/v075/V075MonsterPrivateSkillDock.tscn",
	"military_panel": "res://scenes/ui/v075/V075MilitaryMissionPanel.tscn",
	"top_bar": "res://scenes/ui/TopBar.tscn",
	"planet_board": "res://scenes/ui/PlanetBoard.tscn",
	"context_detail": "res://scenes/ui/table/ContextDetailDrawer.tscn",
	"current_action": "res://scenes/ui/table/CompactCurrentActionSurface.tscn",
	"player_board": "res://scenes/ui/PlayerBoard.tscn",
	"player_card_dock": "res://scenes/ui/table/PlayerCardDock.tscn",
	"hand_rack": "res://scenes/ui/HandRack.tscn",
	"action_dock": "res://scenes/ui/ActionDock.tscn",
	"bid_board": "res://scenes/ui/BidBoard.tscn",
	"top_commodity_track": "res://scenes/ui/table/TopCommoditySushiTrack.tscn",
	"card_resolution_track": "res://scenes/ui/CardResolutionTrack.tscn",
	"overlay_layer": "res://scenes/ui/OverlayLayer.tscn",
	"district_supply": "res://scenes/ui/DistrictSupplyDrawer.tscn",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var roots: Dictionary = {}
	for scene_id_variant: Variant in SCENE_PATHS:
		var scene_id := str(scene_id_variant)
		var scene_path := str(SCENE_PATHS[scene_id])
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s loads as a PackedScene" % scene_path)
		if packed != null:
			roots[scene_id] = packed.instantiate()

	var production_screen := roots.get("production_screen") as Node
	var combat_surface := roots.get("combat_surface") as Node
	var player_board := roots.get("player_board") as Node
	var player_card_dock := roots.get("player_card_dock") as Node
	var commodity_track := roots.get("top_commodity_track") as Node
	var card_track := roots.get("card_resolution_track") as Node
	var overlay := roots.get("overlay_layer") as Node
	var planet_board := roots.get("planet_board") as Node
	var district_supply := roots.get("district_supply") as Node

	_expect(_has_nodes(production_screen, ["Backdrop", "RootMargin", "PlanetBoard", "V074VirtualizedTargetRail", "V075CombatOverlay", "CombatSurface"]), "V075SampleGameScreen composes the inherited sample table, virtualized target rail and combat surface")
	_expect(production_screen != null and production_screen.find_children("V075CombatOverlay", "", true, false).size() == 1 and production_screen.find_children("CombatSurface", "", true, false).size() == 1, "V075SampleGameScreen owns exactly one combat overlay and one combat player surface")
	_expect(_has_nodes(combat_surface, ["PublicMonsterPanel", "SkillDock", "MilitaryPanel", "PresentationStrip"]), "V075CombatPlayerSurface owns public monster, private skill, military mission and presentation regions")
	_expect(_has_nodes(player_board, ["PlayerResourceTableau", "CompactCurrentActionSurface"]) \
		and player_board.find_child("HandRack", true, false) == null \
		and player_board.find_child("PlayerHandTableau", true, false) == null, "shared historical PlayerBoard keeps resources and the compact non-card action context without a legacy hand surface")
	_expect(_has_nodes(player_card_dock, ["BoundActionCards", "NormalHandCards", "CommodityCards", "CardDockCapacitySummary", "CardDockActionFeedback"]), "shared historical PlayerCardDock keeps its three typed card pools, truthful capacity and action feedback")
	_expect(_has_nodes(commodity_track, ["TrackMargin", "TrackRows", "HeaderRow", "TitleLabel", "CommodityTrackPhaseLabel", "CommodityTrackCountLabel", "BeltViewport", "CommodityTrackItemHost", "CommodityTrackEmptyLabel"]), "TopCommoditySushiTrack owns its stable public commodity surface")
	_expect(commodity_track is Control and (commodity_track as Control).custom_minimum_size.y >= 130.0, "TopCommoditySushiTrack remains a readable illustrated table surface instead of the retired 44px banner")
	_expect(_has_nodes(card_track, ["HistoryRail", "ActiveResolutionSlot", "QueueRail", "NextQueueRail", "AuctionResponseLayer", "PrivacyHintLayer", "EmptyStateLayer"]), "CardResolutionTrack owns its complete public resolution surface")
	_expect(_has_nodes(overlay, ["ConfirmPanel", "MonsterWagerDecisionPanel", "TemporaryChoiceDecisionPanel", "PublicBidDecisionPanel"]), "OverlayLayer owns every current temporary decision panel, including structured public_bid")
	_expect(_has_nodes(planet_board, ["WeatherForecastStrip", "PlanetMapView"]), "PlanetBoard owns weather and the sceneized planet map")
	_expect(_has_nodes(district_supply, ["DistrictSupplyMarketGrid", "DistrictSupplyPreviewPanel"]), "DistrictSupplyDrawer owns its market and preview surfaces")

	var main_scene_source := _source("res://scenes/main.tscn")
	var v075_screen_scene_source := _source("res://scenes/ui/v075/V075SampleGameScreen.tscn")
	var v074_screen_scene_source := _source("res://scenes/ui/v074/V074SampleGameScreen.tscn")
	var v073_screen_scene_source := _source("res://scenes/ui/V073SampleGameScreen.tscn")
	var v075_screen_source := _source("res://scripts/ui/v075/v075_sample_game_screen.gd")
	var v074_screen_source := _source("res://scripts/ui/v074/v074_sample_game_screen.gd")
	var v073_screen_source := _source("res://scripts/ui/v073/v073_sample_game_screen.gd")
	var v075_bootstrap_source := _source("res://scripts/v075_runtime/v075_application_bootstrap.gd")
	var v075_application_flow_source := _source("res://scripts/v075_runtime/v075_application_flow.gd")
	var v075_runtime_composition_source := _source("res://scenes/runtime/V075RuntimeComposition.tscn")
	var player_board_source := _source("res://scripts/ui/player_board.gd")
	var public_log_source := _source("res://scripts/presentation/public_log_presentation_owner.gd")
	var presentation_query_source := _source("res://scripts/presentation/table_presentation_viewmodel_query.gd")
	var hand_rack_source := _source("res://scripts/ui/hand_rack.gd")
	var action_dock_source := _source("res://scripts/ui/action_dock.gd")
	var bid_board_source := _source("res://scripts/ui/bid_board.gd")
	var track_source := _source("res://scripts/ui/card_resolution_track.gd")
	var overlay_source := _source("res://scripts/ui/overlay_layer.gd")
	var table_snapshot_source := _source("res://scripts/viewmodels/table_snapshot.gd")

	_expect(_contains_all(main_scene_source, ["res://scripts/v075_runtime/v075_application_bootstrap.gd", "res://scenes/runtime/V075RuntimeComposition.tscn", "res://scenes/ui/v075/V075SampleGameScreen.tscn", "V075RuntimeComposition", "V075GameScreen"]), "main.tscn owns the complete V0.7.5 bootstrap, runtime composition and production screen")
	_expect(v075_screen_scene_source.contains("res://scenes/ui/v074/V074SampleGameScreen.tscn") and v075_screen_scene_source.count("res://scenes/ui/v075/V075CombatPlayerSurface.tscn") == 1 and _contains_all(v075_screen_scene_source, ["V075CombatOverlay", "CombatSurface"]), "V075SampleGameScreen deliberately extends the shared V0.7.4 sample shell and owns one V0.7.5 combat surface")
	_expect(_contains_all(v075_screen_source, ["class_name V075SampleGameScreen", 'const V075_RULESET_ID := "v0.7.5"', "application_intent_requested.emit(intent.duplicate(true))", "_on_private_target_selection_requested", "_on_military_mission_selected"]), "V075SampleGameScreen owns the V0.7.5 ruleset chrome and typed combat intents")
	_expect(v073_screen_source.contains("signal application_intent_requested(intent: Dictionary)") and v073_screen_source.contains("func _emit_intent("), "the inherited sample-screen contract exposes the typed application-intent signal")
	_expect(v075_bootstrap_source.contains("_game_screen.application_intent_requested.connect(") and v075_bootstrap_source.contains('_application_flow.call("submit_intent", intent)'), "V075ApplicationBootstrap routes production-screen intents to the V0.7.5 application flow")
	_expect(v075_application_flow_source.contains("func submit_intent(intent: Dictionary) -> Dictionary:") and v075_application_flow_source.contains("func issue_intent(intent_kind: String, parameters: Dictionary = {}) -> Dictionary:"), "V075ApplicationFlow owns typed intent submission and issuance")
	_expect(_contains_all(v075_runtime_composition_source, ["res://scripts/v075_runtime/v075_application_flow.gd", "V075RulesetRuntimeOwner", "V075RuntimeOwner", "V075CombatRuntimeOwner", "V075CombatTelemetryService"]), "V075RuntimeComposition owns the current ruleset, runtime, combat and telemetry authorities")
	_expect(player_board_source.contains("func set_player_state(data: Dictionary)") \
		and not player_board_source.contains("func set_hand_cards(cards: Array)") \
		and not player_board_source.contains("hand_rack"), "shared historical PlayerBoard exposes structured state without retaining a card action API")
	_expect(public_log_source.contains("LOCALIZED_MESSAGES") and public_log_source.contains("公开局势已更新") and not public_log_source.contains("var message := str(receipt.localization_key)"), "public log renders closed player copy instead of raw localization keys")
	_expect(presentation_query_source.contains('_phase_label(table_phase)') and not presentation_query_source.contains('"state": str(track.get("phase", "空闲"))'), "table state lamp localizes raw runtime phases")
	_expect(hand_rack_source.contains("signal card_selected") and hand_rack_source.contains("signal card_drag_released") and hand_rack_source.contains("func set_cards(cards: Array)"), "HandRack owns card selection and drag interaction")
	_expect(action_dock_source.contains("signal action_requested") and action_dock_source.contains("func set_dock(data: Dictionary)"), "ActionDock owns actionable commands")
	_expect(bid_board_source.contains("signal action_requested") and bid_board_source.contains("func set_bid_state(data: Dictionary)"), "BidBoard owns bid presentation and actions")
	_expect(track_source.contains("signal track_action_requested") and track_source.contains("signal track_entry_selected") and track_source.contains("signal track_entry_opened"), "CardResolutionTrack preserves its public interaction signals")
	_expect(overlay_source.contains("signal temporary_decision_action_requested") and overlay_source.contains("func show_temporary_decision(data: Dictionary)"), "OverlayLayer owns temporary decision routing")
	_expect(table_snapshot_source.contains("PLAYER_BOARD_SNAPSHOT_SCRIPT") and table_snapshot_source.contains("func apply_dictionary(data: Dictionary)"), "TableSnapshot remains the pure-data UI boundary")

	var production_scene_chain := "\n".join([
		main_scene_source,
		v075_screen_scene_source,
		v074_screen_scene_source,
		v073_screen_scene_source,
	])
	var production_owner_chain := "\n".join([
		main_scene_source,
		v075_runtime_composition_source,
		v075_screen_scene_source,
		v074_screen_scene_source,
		v073_screen_scene_source,
		v075_bootstrap_source,
		v075_application_flow_source,
		v075_screen_source,
		v074_screen_source,
		v073_screen_source,
	])
	_expect(not FileAccess.file_exists("res://scripts/main.gd") and not FileAccess.file_exists("res://scripts/main.gd.uid"), "[retired-proof 1/5] scripts/main.gd and its uid are physically absent")
	_expect(not production_scene_chain.contains("res://scenes/ui/GameScreen.tscn"), "[retired-proof 2/5] historical GameScreen.tscn is unreachable from the complete production screen inheritance chain")
	_expect(not _contains_any(production_owner_chain, ["TablePlayerActionApplicationFlowController", "res://scripts/runtime/table_player_action_application_flow_controller.gd"]), "[retired-proof 3/5] the historical table player-action flow is unreachable from the production entry, composition, application flow and screen inheritance owners")
	_expect(not _contains_any(main_scene_source, ["res://scripts/v074_runtime/v074_application_bootstrap.gd", "res://scenes/runtime/V074RuntimeComposition.tscn", 'node name="V074GameScreen"']), "[retired-proof 4/5] V0.7.4 bootstrap/runtime composition are absent from the production entry graph; only the shared sample-screen base remains")

	var v075_combat_surface_scene_text := _source("res://scenes/ui/v075/V075CombatPlayerSurface.tscn")
	var v075_private_skill_scene_text := _source("res://scenes/ui/v075/V075MonsterPrivateSkillDock.tscn")
	var v075_military_scene_text := _source("res://scenes/ui/v075/V075MilitaryMissionPanel.tscn")
	var player_scene_text := _source("res://scenes/ui/PlayerBoard.tscn")
	var player_card_dock_scene_text := _source("res://scenes/ui/table/PlayerCardDock.tscn")
	var top_bar_text := _source("res://scenes/ui/TopBar.tscn")
	var commodity_track_scene_text := _source("res://scenes/ui/table/TopCommoditySushiTrack.tscn")
	var commodity_track_source := _source("res://scripts/ui/table/top_commodity_sushi_track.gd")
	var track_scene_text := _source("res://scenes/ui/CardResolutionTrack.tscn")
	var overlay_scene_text := _source("res://scenes/ui/OverlayLayer.tscn")
	var menu_overlay_scene_text := _source("res://scenes/ui/MenuOverlay.tscn")
	var menu_overlay_source := _source("res://scripts/ui/menu_overlay.gd")
	var monster_token_scene_text := _source("res://scenes/ui/map/PlanetMonsterToken.tscn")
	var monster_token_source := _source("res://scripts/ui/map/planet_monster_token.gd")
	var planet_map_source := _source("res://scripts/ui/planet_map_view.gd")
	var district_node_source := _source("res://scripts/ui/map/planet_district_node.gd")
	var district_info_source := _source("res://scripts/ui/district_info_panel.gd")
	_expect(_contains_all(v075_screen_scene_source, ["DIRECT ACTION", "等待战斗投影", "收起战斗投影", 'text = "收起"', "公开行动 ACTION FEED", "当前行动 · 请选择卡牌", 'text = "PAUSE"']), "V075SampleGameScreen gives the single-screen action, feed, and pacing surfaces readable player-facing defaults")
	_expect(_contains_all(v075_combat_surface_scene_text, ["怪兽", "本批可用", "公开战斗回执"]), "V075CombatPlayerSurface gives public monster and combat receipt regions readable defaults")
	_expect(_contains_all(v075_private_skill_scene_text, ["怪兽 · 私密技能", "仅自己可见", "当前没有可显示的怪兽技能"]), "V075 private skill dock states its owner-only privacy and empty state")
	_expect(_contains_all(v075_military_scene_text, ["军队任务", "攻击后撤离", "地区目标", "怪兽目标", "攻击地区", "攻击怪兽"]), "V075 military mission panel exposes readable target and action copy")
	_expect(_contains_all(player_scene_text, ["玩家状态", "现金｜", "GDP｜", "选区｜", "下一步｜"]), "shared historical PlayerBoard keeps concise player-facing Chinese status defaults")
	_expect(_contains_all(player_card_dock_scene_text, ["玩家卡牌坞", "当前 V0.6 共享容量", "绑定行动", "普通牌", "商品牌"]), "shared historical PlayerCardDock explains its three pools and truthful V0.6 capacity")
	_expect(_contains_all(top_bar_text, ["桌态｜待开桌", "计时｜00:00", "结束操作", "菜单"]), "TopBar keeps readable table status and commands")
	_expect(_contains_all(commodity_track_scene_text, ["公共商品寿司带", "等待权威快照", "0 件公开商品", "共享商品带尚未就绪。"]), "TopCommoditySushiTrack explains its public commodity state")
	_expect(_contains_all(commodity_track_source, ["signal item_focused", "signal claim_requested", "func set_snapshot(snapshot:"]), "TopCommoditySushiTrack exposes typed commodity focus, claim, and snapshot boundaries")
	_expect(_contains_all(track_scene_text, ["公共牌轨", "竞价/响应窗口", "归属未公开前只显示待猜线索", "牌轨空闲"]), "CardResolutionTrack explains public state without owner leakage")
	_expect(_contains_all(overlay_scene_text, ["详情抽屉", "确认操作", "MonsterWagerDecisionPanel", "TemporaryChoiceDecisionPanel"]), "OverlayLayer exposes scene-owned detail and decision surfaces")
	_expect(_contains_all(menu_overlay_scene_text, ["text = \"返回\""]) and not menu_overlay_scene_text.contains("text = \"Back\""), "MenuOverlay keeps default navigation player-facing and localized")
	_expect(menu_overlay_source.contains("data.get(\"back_text\", \"返回\")"), "MenuOverlay catalog navigation keeps a localized fallback")
	_expect(monster_token_scene_text.contains("text = \"场上单位\"") and monster_token_source.contains("data.get(\"detail_label\", \"场上单位\")") and not monster_token_source.contains("data.get(\"motif\""), "PlanetMonsterToken never renders internal visual motif ids")
	_expect(planet_map_source.contains("marker.get(\"display_subtitle\", \"场上单位\")") and not planet_map_source.contains("\"motif\": str(marker.get(\"motif\""), "PlanetMapView passes only player-facing monster token copy")
	_expect(planet_map_source.contains("_terrain_display_label") and planet_map_source.contains("\"detail\": \"当前焦点｜%s\" % _terrain_display_label"), "PlanetMapView renders a player-facing terrain label for the selected focus")
	_expect(district_node_source.contains("\"ocean\": \"海洋\"") and district_node_source.contains("\"land\": \"陆地\""), "PlanetDistrictNode renders player-facing terrain labels")
	_expect(district_info_source.contains("\"shipping\": \"航运\"") and district_info_source.contains("\"factory\": \"工厂\"") and district_info_source.contains("label.tooltip_text = _player_facing_detail"), "DistrictInfoPanel renders public facility labels and hover copy instead of machine enums")

	var player_facing_sources := "\n".join([
		v075_screen_scene_source,
		v075_combat_surface_scene_text,
		v075_private_skill_scene_text,
		v075_military_scene_text,
		player_scene_text,
		player_card_dock_scene_text,
		top_bar_text,
		track_scene_text,
		overlay_scene_text,
	])
	_expect(not _contains_any(player_facing_sources, ["即时原型", "测试阶段优先快速迭代", "可复用UI", "AI 内部路线", "临时美工"]), "scene-owned player surfaces avoid developer-facing copy")

	for root_variant: Variant in roots.values():
		var root := root_variant as Node
		if root != null:
			root.free()
	_finish()


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _has_nodes(root: Node, node_names: Array) -> bool:
	if root == null:
		return false
	for node_name_variant: Variant in node_names:
		if root.find_child(str(node_name_variant), true, false) == null:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("UI text smoke failure: %s" % message)


func _contains_any(text: String, needles: Array) -> bool:
	for needle_variant: Variant in needles:
		if text.contains(str(needle_variant)):
			return true
	return false


func _contains_all(text: String, needles: Array) -> bool:
	for needle_variant: Variant in needles:
		if not text.contains(str(needle_variant)):
			return false
	return true


func _finish() -> void:
	if _failures.is_empty():
		print("UI text smoke test passed.")
		quit(0)
	else:
		print("UI text smoke test failed: %s" % " / ".join(_failures))
		quit(1)
