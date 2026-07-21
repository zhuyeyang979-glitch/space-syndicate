extends SceneTree

const SCENE_PATHS := {
	"game_screen": "res://scenes/ui/GameScreen.tscn",
	"top_bar": "res://scenes/ui/TopBar.tscn",
	"planet_board": "res://scenes/ui/PlanetBoard.tscn",
	"right_inspector": "res://scenes/ui/RightInspector.tscn",
	"player_board": "res://scenes/ui/PlayerBoard.tscn",
	"hand_rack": "res://scenes/ui/HandRack.tscn",
	"action_dock": "res://scenes/ui/ActionDock.tscn",
	"bid_board": "res://scenes/ui/BidBoard.tscn",
	"top_commodity_track": "res://scenes/ui/table/TopCommoditySushiTrack.tscn",
	"card_resolution_track": "res://scenes/ui/CardResolutionTrack.tscn",
	"overlay_layer": "res://scenes/ui/OverlayLayer.tscn",
	"district_supply": "res://scenes/ui/DistrictSupplyDrawer.tscn",
}

const RETIRED_PLAYER_SURFACE_HELPERS := [
	"_add_player_hand_rack",
	"_add_player_action_tray",
	"_add_selected_district_action_panel",
	"_add_first_summon_prompt",
	"_add_player_resource_cubes",
	"_add_player_tableau",
	"_add_player_seat_cards",
	"_inspect_player_public_profile",
	"_clear_player_public_inspection",
	"_dismiss_opening_guide",
	"_role_card_art_stats",
	"_respond_to_active_contract",
]

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

	var game_screen := roots.get("game_screen") as Node
	var player_board := roots.get("player_board") as Node
	var commodity_track := roots.get("top_commodity_track") as Node
	var card_track := roots.get("card_resolution_track") as Node
	var overlay := roots.get("overlay_layer") as Node
	var planet_board := roots.get("planet_board") as Node
	var district_supply := roots.get("district_supply") as Node

	_expect(_has_nodes(game_screen, ["TopBar", "TopCommoditySushiTrack", "PlanetBoard", "RightInspector", "PlayerBoard", "OverlayLayer"]), "GameScreen composes the current commodity-led table scenes")
	_expect(game_screen != null and game_screen.find_child("PublicTrack", true, false) == null, "GameScreen keeps the retired PublicTrack out of active production composition")
	_expect(game_screen != null and game_screen.find_children("TopCommoditySushiTrack", "", true, false).size() == 1, "GameScreen composes exactly one TopCommoditySushiTrack")
	_expect(_has_nodes(game_screen, ["RuntimeVisualEventLayer"]) and not _has_nodes(game_screen, ["FirstRunCoach", "ScenarioCoach"]), "GameScreen keeps runtime feedback and removes legacy coach surfaces")
	_expect(_has_nodes(player_board, ["PlayerResourceTableau", "HandRack", "PlayerMainActionDock"]) and player_board.find_child("PlayerBidBoard", true, false) == null, "PlayerBoard owns resources, hand, and actions without reserving a permanent bid surface")
	_expect(_has_nodes(commodity_track, ["TrackMargin", "TrackRows", "HeaderRow", "TitleLabel", "CommodityTrackPhaseLabel", "CommodityTrackCountLabel", "BeltViewport", "CommodityTrackItemHost", "CommodityTrackEmptyLabel"]), "TopCommoditySushiTrack owns its stable public commodity surface")
	_expect(commodity_track is Control and (commodity_track as Control).custom_minimum_size.y >= 150.0, "TopCommoditySushiTrack remains a wide table surface instead of the retired 44px banner")
	_expect(_has_nodes(card_track, ["HistoryRail", "ActiveResolutionSlot", "QueueRail", "NextQueueRail", "AuctionResponseLayer", "PrivacyHintLayer", "EmptyStateLayer"]), "CardResolutionTrack owns its complete public resolution surface")
	_expect(_has_nodes(overlay, ["ConfirmPanel", "MonsterWagerDecisionPanel", "TemporaryChoiceDecisionPanel", "PublicBidDecisionPanel"]), "OverlayLayer owns every current temporary decision panel, including structured public_bid")
	_expect(_has_nodes(planet_board, ["WeatherForecastStrip", "PlanetMapView"]), "PlanetBoard owns weather and the sceneized planet map")
	_expect(_has_nodes(district_supply, ["DistrictSupplyMarketGrid", "DistrictSupplyPreviewPanel"]), "DistrictSupplyDrawer owns its market and preview surfaces")

	var main_source := _source("res://scripts/main.gd")
	var main_scene_source := _source("res://scenes/main.tscn")
	var game_screen_source := _source("res://scripts/ui/game_screen.gd")
	var player_board_source := _source("res://scripts/ui/player_board.gd")
	var public_log_source := _source("res://scripts/presentation/public_log_presentation_owner.gd")
	var presentation_query_source := _source("res://scripts/presentation/table_presentation_viewmodel_query.gd")
	var hand_rack_source := _source("res://scripts/ui/hand_rack.gd")
	var action_dock_source := _source("res://scripts/ui/action_dock.gd")
	var bid_board_source := _source("res://scripts/ui/bid_board.gd")
	var track_source := _source("res://scripts/ui/card_resolution_track.gd")
	var overlay_source := _source("res://scripts/ui/overlay_layer.gd")
	var table_snapshot_source := _source("res://scripts/viewmodels/table_snapshot.gd")

	_expect(main_scene_source.contains("RuntimeGameScreen") and main_scene_source.contains("GameScreen.tscn"), "main.tscn embeds the sceneized GameScreen")
	_expect(game_screen_source.contains("func apply_state(data: Dictionary)") and game_screen_source.contains("TABLE_SNAPSHOT_SCRIPT"), "GameScreen consumes the table snapshot bridge")
	_expect(game_screen_source.contains("signal action_requested") and game_screen_source.contains("signal card_selected") and game_screen_source.contains("temporary_decision_action_requested"), "GameScreen forwards player and decision signals")
	_expect(player_board_source.contains("func set_player_state(data: Dictionary)") and player_board_source.contains("func set_hand_cards(cards: Array)"), "PlayerBoard exposes structured state and hand APIs")
	_expect(public_log_source.contains("LOCALIZED_MESSAGES") and public_log_source.contains("公开局势已更新") and not public_log_source.contains("var message := str(receipt.localization_key)"), "public log renders closed player copy instead of raw localization keys")
	_expect(presentation_query_source.contains('_phase_label(table_phase)') and not presentation_query_source.contains('"state": str(track.get("phase", "空闲"))'), "table state lamp localizes raw runtime phases")
	_expect(hand_rack_source.contains("signal card_selected") and hand_rack_source.contains("signal card_drag_released") and hand_rack_source.contains("func set_cards(cards: Array)"), "HandRack owns card selection and drag interaction")
	_expect(action_dock_source.contains("signal action_requested") and action_dock_source.contains("func set_dock(data: Dictionary)"), "ActionDock owns actionable commands")
	_expect(bid_board_source.contains("signal action_requested") and bid_board_source.contains("func set_bid_state(data: Dictionary)"), "BidBoard owns bid presentation and actions")
	_expect(track_source.contains("signal track_action_requested") and track_source.contains("signal track_entry_selected") and track_source.contains("signal track_entry_opened"), "CardResolutionTrack preserves its public interaction signals")
	_expect(overlay_source.contains("signal temporary_decision_action_requested") and overlay_source.contains("func show_temporary_decision(data: Dictionary)"), "OverlayLayer owns temporary decision routing")
	_expect(table_snapshot_source.contains("PLAYER_BOARD_SNAPSHOT_SCRIPT") and table_snapshot_source.contains("func apply_dictionary(data: Dictionary)"), "TableSnapshot remains the pure-data UI boundary")

	_expect(not main_source.contains("func _runtime_table_snapshot_source") and not main_source.contains("func _sync_runtime_game_screen") and main_source.contains("func _on_runtime_game_screen_action_requested"), "main.gd keeps action routing while scene-owned presentation owns snapshots and targets")
	_expect(not main_source.contains("BUILD_LEGACY_RUNTIME_TABLE") and not main_scene_source.contains("LegacyRuntimeTable"), "legacy runtime table composition stays retired")
	for helper_variant: Variant in RETIRED_PLAYER_SURFACE_HELPERS:
		var helper_name := str(helper_variant)
		_expect(not main_source.contains("func %s(" % helper_name), "%s remains retired from main.gd" % helper_name)

	var player_scene_text := _source("res://scenes/ui/PlayerBoard.tscn")
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
	_expect(_contains_all(player_scene_text, ["玩家板｜手牌", "现金｜", "GDP｜", "选区｜", "下一步｜", "手牌｜"]), "PlayerBoard keeps concise player-facing Chinese defaults")
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

	var player_facing_sources := "\n".join([player_scene_text, top_bar_text, track_scene_text, overlay_scene_text])
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
