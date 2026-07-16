extends SceneTree

const VISUAL_SCENES := [
	"res://scenes/ui/GameScreen.tscn",
	"res://scenes/ui/PlayerBoard.tscn",
	"res://scenes/ui/CardFace.tscn",
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

const RETIRED_GENERATED_UI_HELPERS := [
	"_add_player_hand_rack",
	"_add_player_action_tray",
	"_add_selected_district_action_panel",
	"_add_first_summon_prompt",
	"_add_player_resource_cubes",
	"_add_player_tableau",
	"_add_player_seat_cards",
	"_add_bid_control_card",
	"_add_owner_guess_card",
	"_add_card_resolution_track",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path_variant: Variant in VISUAL_SCENES + MAP_COMPONENT_SCENES:
		var scene_path := str(scene_path_variant)
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s loads as a visual scene" % scene_path)

	var game_screen := _instantiate("res://scenes/ui/GameScreen.tscn")
	var player_board := _instantiate("res://scenes/ui/PlayerBoard.tscn")
	var planet_map := _instantiate("res://scenes/ui/PlanetMapView.tscn")
	var card_track := _instantiate("res://scenes/ui/CardResolutionTrack.tscn")
	var overlay := _instantiate("res://scenes/ui/OverlayLayer.tscn")

	_expect(_has_nodes(game_screen, ["Background", "TopBar", "PublicTrack", "PlanetBoard", "RightInspector", "PlayerBoard", "OverlayLayer"]), "GameScreen provides the complete scene-owned table composition")
	_expect(_has_nodes(player_board, ["PlayerResourceTableau", "PlayerHandTableau", "HandRack", "PlayerCommandTableau", "PlayerMainActionDock"]) and player_board.find_child("PlayerBidBoard", true, false) == null, "PlayerBoard has stable resource, hand, and action regions with zero permanent bid footprint")
	_expect(_has_nodes(planet_map, ["BackdropLayer", "OrbitLayer", "DistrictLayer", "RouteLayer", "MonsterLayer", "SelectionLayer", "EffectLayer", "CalloutLayer", "DebugOverlayLayer"]), "PlanetMapView exposes editable visual layers")
	_expect(_has_nodes(card_track, ["HistoryRail", "ActiveResolutionSlot", "QueueRail", "NextQueueRail", "AuctionResponseLayer", "PrivacyHintLayer"]), "CardResolutionTrack exposes stable visual lanes and privacy feedback")
	_expect(_has_nodes(overlay, ["SideDrawerLayer", "TooltipLayer", "DragPreviewLayer", "ModalLayer", "RuntimeSurfaceLayer", "PublicBidDecisionPanel"]), "OverlayLayer separates detail, pointer, transient bid, decision, and runtime surfaces")

	var main_source := _source("res://scripts/main.gd")
	var main_scene_source := _source("res://scenes/main.tscn")
	var map_scene_source := _source("res://scenes/ui/PlanetMapView.tscn")
	var map_script_source := _source("res://scripts/ui/planet_map_view.gd")
	var card_face_source := _source("res://scripts/ui/card_face.gd")
	var card_art_source := _source("res://scripts/card_art_view.gd")
	var monster_art_source := _source("res://scripts/monster_art_view.gd")
	var visual_event_source := _source("res://scripts/ui/visual_event_layer.gd")
	var targeting_source := _source("res://scripts/ui/targeting_overlay.gd")

	_expect(main_scene_source.contains("GameScreen.tscn") and main_scene_source.contains("RuntimeGameScreen"), "main.tscn embeds the real GameScreen")
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

	_expect(not main_source.contains("BUILD_LEGACY_RUNTIME_TABLE") and not main_scene_source.contains("LegacyRuntimeTable"), "legacy generated table stays retired")
	for helper_variant: Variant in RETIRED_GENERATED_UI_HELPERS:
		var helper_name := str(helper_variant)
		_expect(not main_source.contains("func %s(" % helper_name), "%s stays outside main.gd" % helper_name)

	for node in [game_screen, player_board, planet_map, card_track, overlay]:
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
