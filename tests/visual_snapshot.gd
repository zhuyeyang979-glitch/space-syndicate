extends SceneTree

const VISUAL_SCENES := [
	"res://scenes/ui/v075/V075SampleGameScreen.tscn",
	"res://scenes/ui/v075/V075CombatPlayerSurface.tscn",
	"res://scenes/ui/v075/V075MonsterPrivateSkillDock.tscn",
	"res://scenes/ui/v075/V075MilitaryMissionPanel.tscn",
	"res://scenes/ui/PlayerBoard.tscn",
	"res://scenes/ui/CardFace.tscn",
	"res://scenes/ui/table/TopCommoditySushiTrack.tscn",
	"res://scenes/ui/CardResolutionTrack.tscn",
	"res://scenes/ui/PlanetMapView.tscn",
	"res://scenes/ui/OverlayLayer.tscn",
	"res://scenes/ui/VisualEventLayer.tscn",
	"res://scenes/ui/TargetingOverlay.tscn",
	"res://scenes/ui/VerticalSliceShowcase.tscn",
]

const MAP_COMPONENT_SCENES := [
	"res://scenes/ui/map/PlanetGlobeBackdrop.tscn",
	"res://scenes/ui/map/PlanetOrbitGuide.tscn",
	"res://scenes/ui/map/PlanetDistrictPolygon.tscn",
	"res://scenes/ui/map/PlanetDistrictNode.tscn",
	"res://scenes/ui/map/PlanetRouteSegment.tscn",
	"res://scenes/ui/map/PlanetMovementTrail.tscn",
	"res://scenes/ui/map/PlanetMapEventEffect.tscn",
	"res://scenes/ui/map/PlanetActionCallout.tscn",
	"res://scenes/ui/map/PlanetCityMarker.tscn",
	"res://scenes/ui/map/PlanetMonsterToken.tscn",
	"res://scenes/ui/map/PlanetRouteMarker.tscn",
	"res://scenes/ui/map/PlanetSelectionRing.tscn",
	"res://scenes/ui/map/PlanetFocusRangeOverlay.tscn",
	"res://scenes/ui/map/PlanetMapScaleHint.tscn",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path_variant: Variant in VISUAL_SCENES + MAP_COMPONENT_SCENES:
		var scene_path := str(scene_path_variant)
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s loads as a visual scene" % scene_path)

	var production_screen := _instantiate("res://scenes/ui/v075/V075SampleGameScreen.tscn")
	var combat_surface := _instantiate("res://scenes/ui/v075/V075CombatPlayerSurface.tscn")
	var player_board := _instantiate("res://scenes/ui/PlayerBoard.tscn")
	var player_card_dock := _instantiate("res://scenes/ui/table/PlayerCardDock.tscn")
	var planet_map := _instantiate("res://scenes/ui/PlanetMapView.tscn")
	var commodity_track := _instantiate("res://scenes/ui/table/TopCommoditySushiTrack.tscn")
	var card_track := _instantiate("res://scenes/ui/CardResolutionTrack.tscn")
	var overlay := _instantiate("res://scenes/ui/OverlayLayer.tscn")

	_expect(_has_nodes(production_screen, ["Backdrop", "RootMargin", "PlanetBoard", "V074VirtualizedTargetRail", "V075CombatOverlay", "CombatSurface"]), "V075SampleGameScreen exposes the inherited table shell, V0.7.4 target rail and V0.7.5 combat overlay")
	_expect(production_screen != null and production_screen.find_children("V075CombatOverlay", "", true, false).size() == 1 and production_screen.find_children("CombatSurface", "", true, false).size() == 1, "V075SampleGameScreen composes exactly one combat overlay and one combat player surface")
	_expect(_has_nodes(combat_surface, ["PublicMonsterPanel", "SkillDock", "MilitaryPanel", "PresentationStrip"]), "V075CombatPlayerSurface exposes its four stable visual regions")
	_expect(_has_nodes(player_board, ["PlayerResourceTableau", "PlayerCommandTableau", "CompactCurrentActionSurface"]) \
		and player_board.find_child("PlayerHandTableau", true, false) == null \
		and player_board.find_child("HandRack", true, false) == null, "shared historical PlayerBoard retains resources and one compact non-card action context")
	_expect(_has_nodes(player_card_dock, ["BoundActionCards", "NormalHandCards", "CommodityCards", "CardDockCapacitySummary", "CardDockActionFeedback"]), "shared historical PlayerCardDock exposes three readable typed card lanes and feedback")
	_expect(_has_nodes(planet_map, ["BackdropLayer", "OrbitLayer", "DistrictLayer", "RouteLayer", "MonsterLayer", "SelectionLayer", "EffectLayer", "CalloutLayer", "DebugOverlayLayer"]), "PlanetMapView exposes editable visual layers")
	_expect(_has_nodes(commodity_track, ["TrackMargin", "HeaderRow", "BeltViewport", "CommodityTrackItemHost", "CommodityTrackEmptyLabel"]), "TopCommoditySushiTrack exposes stable header, belt, item, and empty-state regions")
	_expect(_has_nodes(card_track, ["HistoryRail", "ActiveResolutionSlot", "QueueRail", "NextQueueRail", "AuctionResponseLayer", "PrivacyHintLayer"]), "CardResolutionTrack exposes stable visual lanes and privacy feedback")
	_expect(_has_nodes(overlay, ["SideDrawerLayer", "TooltipLayer", "DragPreviewLayer", "ModalLayer", "RuntimeSurfaceLayer", "PublicBidDecisionPanel"]), "OverlayLayer separates detail, pointer, transient bid, decision, and runtime surfaces")

	var main_scene_source := _source("res://scenes/main.tscn")
	var v075_screen_scene_source := _source("res://scenes/ui/v075/V075SampleGameScreen.tscn")
	var v075_screen_source := _source("res://scripts/ui/v075/v075_sample_game_screen.gd")
	var v075_bootstrap_source := _source("res://scripts/v075_runtime/v075_application_bootstrap.gd")
	var v075_application_flow_source := _source("res://scripts/v075_runtime/v075_application_flow.gd")
	var v075_runtime_composition_source := _source("res://scenes/runtime/V075RuntimeComposition.tscn")
	var map_scene_source := _source("res://scenes/ui/PlanetMapView.tscn")
	var map_script_source := _source("res://scripts/ui/planet_map_view.gd")
	var card_face_source := _source("res://scripts/ui/card_face.gd")
	var card_art_source := _source("res://scripts/card_art_view.gd")
	var monster_art_source := _source("res://scripts/monster_art_view.gd")
	var visual_event_source := _source("res://scripts/ui/visual_event_layer.gd")
	var targeting_source := _source("res://scripts/ui/targeting_overlay.gd")

	_expect(_contains_all(main_scene_source, ["res://scripts/v075_runtime/v075_application_bootstrap.gd", "res://scenes/runtime/V075RuntimeComposition.tscn", "res://scenes/ui/v075/V075SampleGameScreen.tscn", "V075RuntimeComposition", "V075GameScreen"]), "main.tscn embeds the complete V0.7.5 production composition")
	_expect(v075_screen_scene_source.contains("res://scenes/ui/v074/V074SampleGameScreen.tscn") and v075_screen_scene_source.count("res://scenes/ui/v075/V075CombatPlayerSurface.tscn") == 1 and _contains_all(v075_screen_scene_source, ["V075CombatOverlay", "CombatSurface"]), "V075SampleGameScreen deliberately extends the shared V0.7.4 shell and sceneizes exactly one V0.7.5 combat surface")
	_expect(production_screen != null and production_screen.has_method("v075_responsive_geometry_audit") and production_screen.get_node_or_null("RootMargin") is ScrollContainer and _contains_all(v075_screen_source, ["root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED", "root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED", "root_scroll.follow_focus = false"]), "V075SampleGameScreen exposes a runtime geometry audit and owns a deterministic production root-scroll disable contract")
	_expect(v075_bootstrap_source.contains("_game_screen.application_intent_requested.connect(") and v075_bootstrap_source.contains('_application_flow.call("submit_intent", intent)'), "V075ApplicationBootstrap connects the production screen to the current application flow")
	_expect(v075_application_flow_source.contains("func submit_intent(intent: Dictionary) -> Dictionary:") and _contains_all(v075_runtime_composition_source, ["V075RulesetRuntimeOwner", "V075RuntimeOwner", "V075CombatRuntimeOwner", "V075CombatTelemetryService"]), "V075RuntimeComposition exposes the current typed application flow and runtime owners")
	_expect(_has_no_nodes(production_screen, ["RuntimeGameScreen", "TopCommoditySushiTrack", "PlayerRosterPanel", "PlayerBoard", "PlayerCardDock", "ContextDetailDrawer"]), "[retired-proof 5/5] the instantiated V0.7.5 production screen has none of the historical split-shell GameScreen nodes")
	_expect(map_scene_source.contains("PlanetGlobeBackdrop") and map_scene_source.contains("PlanetFocusRangeOverlay") and map_scene_source.contains("PlanetMapScaleHint"), "PlanetMapView keeps stable editor-visible anchor components")
	_expect(map_script_source.contains("sceneized_visual_cutover_enabled := true") and map_script_source.contains("legacy_draw_fallback_enabled := false"), "sceneized map rendering remains the default")
	_expect(map_script_source.contains("PlanetDistrictPolygonScene") and map_script_source.contains("PlanetRouteSegmentScene") and map_script_source.contains("PlanetMonsterTokenScene"), "map render ownership resolves to component scenes")
	_expect(card_face_source.contains("class_name SpaceSyndicateCardFace") and card_face_source.contains("func set_card_data(data: Dictionary)"), "CardFace is a reusable scene wrapper with a structured data API")
	_expect(card_art_source.contains("card_visual_profile_snapshot") and monster_art_source.contains("monster_visual_profile_snapshot"), "card and monster art expose reviewable visual profiles")
	_expect(visual_event_source.contains("func set_visual_events(events: Array") and visual_event_source.contains("func add_visual_event(event_data: Dictionary)"), "VisualEventLayer exposes structured runtime visual-event entry points")
	_expect(targeting_source.contains("target") and targeting_source.contains("func"), "TargetingOverlay retains its targeting presentation implementation")

	_expect(FileAccess.file_exists("res://docs/card_visual_theme_contract.md"), "card visual theme contract exists")
	_expect(FileAccess.file_exists("res://docs/art_production_contract.md"), "art production contract exists")
	_expect(FileAccess.file_exists("res://docs/vfx_event_language.md"), "VFX event language exists")
	_expect(FileAccess.file_exists("res://tests/art_identity_gate_test.gd"), "art identity gate exists")
	_expect(FileAccess.file_exists("res://assets/third_party/moth_kaijuice/LICENSE"), "Moth Kaijuice attribution is present")
	_expect(FileAccess.file_exists("res://assets/third_party/monster_battler/LICENSE"), "Monster Battler attribution is present")
	_expect(FileAccess.file_exists("res://assets/third_party/kenney_cc0/LICENSE.md"), "Kenney attribution is present")
	_expect(FileAccess.file_exists("res://assets/third_party/game_icons_ccby/license.txt"), "Game-icons attribution is present")

	for node in [production_screen, combat_surface, player_board, player_card_dock, planet_map, commodity_track, card_track, overlay]:
		if node != null:
			node.free()
	_finish()


func _instantiate(path: String) -> Node:
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _has_nodes(root: Node, node_names: Array) -> bool:
	if root == null:
		return false
	for node_name_variant: Variant in node_names:
		if root.find_child(str(node_name_variant), true, false) == null:
			return false
	return true


func _has_no_nodes(root: Node, node_names: Array) -> bool:
	if root == null:
		return false
	for node_name_variant: Variant in node_names:
		if root.find_child(str(node_name_variant), true, false) != null:
			return false
	return true


func _contains_all(text: String, needles: Array) -> bool:
	for needle_variant: Variant in needles:
		if not text.contains(str(needle_variant)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("Visual contract failure: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Visual contract test passed.")
		quit(0)
	else:
		print("Visual contract test failed: %s" % " / ".join(_failures))
		quit(1)
