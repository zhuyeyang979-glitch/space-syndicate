extends SceneTree

const SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	root.add_child(screen)
	await process_frame
	var dock_nodes := screen.find_children("PlayerCardDock", "", true, false)
	var dock := screen.find_child("PlayerCardDock", true, false) as SpaceSyndicatePlayerCardDock
	var player_board := screen.find_child("PlayerBoard", true, false)
	_expect(dock_nodes.size() == 1 and dock != null, "production GameScreen composes exactly one PlayerCardDock")
	_expect(screen.find_children("RightInspector", "", true, false).size() == 1, "RightInspector remains in production for this narrow cutover")
	_expect(screen.find_child("PlayerRoster", true, false) == null 		and screen.find_child("RegionSupplyPopup", true, false) == null 		and screen.find_child("ContextDetailPopup", true, false) == null, "later Alpha 0.4 shell surfaces remain out of scope")
	_expect(player_board != null 		and player_board.find_child("HandRack", true, false) == null 		and player_board.find_child("PlayerHandTableau", true, false) == null 		and player_board.find_child("PlayerHandCountChip", true, false) == null, "legacy production HandRack, tableau, and count chip are physically absent")
	_expect(_has_nodes(dock, [
		"BoundActionCards",
		"NormalHandCards",
		"CommodityCards",
		"CardDockCapacitySummary",
		"CardDockActionFeedback",
	]), "PlayerCardDock exposes all typed pool targets and feedback")
	_expect(dock.custom_minimum_size.y >= 180.0, "production Dock reserves readable card height")
	_expect(screen.get_combined_minimum_size().x <= 1366.0, "production GameScreen remains within the 1366-wide acceptance viewport")

	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	_expect(coordinator.find_children("PlayerCardDockViewerQueryPort", "", true, false).size() == 1, "GameRuntimeCoordinator composes exactly one viewer query port")
	_expect(coordinator.find_children("TablePlayerActionApplicationFlowController", "", true, false).size() == 1, "GameRuntimeCoordinator keeps one Action Spine application flow")
	coordinator.queue_free()

	var screen_scene := _source("res://scenes/ui/GameScreen.tscn")
	var player_board_scene := _source("res://scenes/ui/PlayerBoard.tscn")
	var screen_source := _source("res://scripts/ui/game_screen.gd")
	var player_board_source := _source("res://scripts/ui/player_board.gd")
	var dock_source := _source("res://scripts/ui/table/player_card_dock.gd")
	var projection_source := _source("res://scripts/presentation/player_card_dock_projection_v1.gd")
	var query_source := _source("res://scripts/presentation/player_card_dock_viewer_query_port.gd")
	var source_owner := _source("res://scripts/presentation/table_presentation_source_owner.gd")
	var table_snapshot := _source("res://scripts/viewmodels/table_snapshot.gd")
	var table_viewmodel := _source("res://scripts/runtime/game_table_viewmodel_runtime_service.gd")
	var coordinator_scene := _source("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var coordinator_source := _source("res://scripts/runtime/game_runtime_coordinator.gd")
	var main_scene := _source("res://scenes/main.tscn")
	var main_source := _source("res://scripts/main.gd")
	var selection_intent := _source("res://scripts/runtime/table_selection_intent.gd")

	_expect(screen_scene.count("PlayerCardDock.tscn") == 1 		and coordinator_scene.count("PlayerCardDockViewerQueryPort.tscn") == 1, "production source and target scenes each appear once")
	_expect(not player_board_scene.contains("HandRack.tscn") 		and not player_board_scene.contains("PlayerHandTableau") 		and not player_board_scene.contains("PlayerHandCountChip"), "PlayerBoard scene contains no hidden legacy hand surface")
	_expect(not player_board_source.contains("hand_rack") 		and not player_board_source.contains("signal card_selected") 		and not player_board_source.contains("func set_hand_cards"), "PlayerBoard script contains no legacy card action bridge")
	_expect(screen_source.contains("player_card_dock.game_action_offer_requested.connect") 		and screen_source.contains("func _on_game_action_offer_requested(") 		and screen_source.contains("func submit_game_action_offer("), "Dock routes offers through the existing typed GameScreen action bridge")
	_expect(not screen_source.contains("player_board.has_signal(\"card_selected\")") 		and not screen_source.contains("&\"hand_rack\"") 		and not screen_source.contains("func _on_card_drag_released"), "GameScreen has no old HandRack or drag submission route")
	_expect(screen_source.contains("func _retire_right_inspector_card_actions(") 		and screen_source.contains("read_only_details[\"actions\"] = []"), "retained RightInspector is read-only for Dock cards")
	_expect(dock_source.contains("CARD_FACE_SCENE.instantiate()") 		and dock_source.contains("game_action_offer_requested.emit") 		and not dock_source.contains("CommodityCardInventoryRuntimeController") 		and not dock_source.contains("/root/Main"), "Dock renders real CardFace nodes and owns no inventory or Main mutation")
	_expect(projection_source.contains("CAPACITY_MODE_SHARED_V06") 		and projection_source.contains("CAPACITY_MODE_INDEPENDENT_V07") 		and projection_source.contains("slot_id") 		and projection_source.contains("disabled_reason_text"), "typed projection carries truthful dual-mode capacity and readable card identity")
	_expect(query_source.contains("can_view_private_subject") 		and query_source.contains("expected_authorization_revision") 		and query_source.contains("stores_card_state\": false"), "viewer query fails closed and stores no cards")
	_expect(source_owner.contains("compose_table_state_bundle") \
		and source_owner.contains("player_card_dock_query.snapshot_for_viewer_with_composed_cards") \
		and table_viewmodel.contains("include_player_card_dock_bundle") \
		and table_snapshot.contains("PLAYER_CARD_DOCK_PROJECTION_SCRIPT.detached_copy"), "scene-owned source reuses one composed hand bundle for the typed Dock projection")
	_expect(not table_viewmodel.contains("player_board[\"hand_cards\"]"), "legacy PlayerBoard hand snapshot injection is retired")
	_expect(coordinator_source.contains("player_card_dock_query.configure(") 		and coordinator_source.contains("_player_card_dock_viewer_query_port_node"), "Coordinator explicitly wires the typed viewer query")
	_expect(main_scene.count("signal=\"game_action_intent_requested\"") == 1 		and main_scene.count("method=\"submit_intent\"") >= 1, "main scene keeps one typed GameActionIntent connection")
	_expect(not main_source.contains("PlayerCardDock") 		and not main_source.contains("player_card_dock"), "main.gd gains no Player Card Dock responsibility")
	_expect(selection_intent.contains("&\"player_card_dock\"") 		and not selection_intent.contains("&\"hand_rack\""), "typed hand selection accepts only the production Dock surface")
	_expect(screen_source.contains("player_card_dock.target_selection_active()") 		and screen_source.contains("submit_target_selection(_pending_card_target_region_id)"), "commodity target selection waits for an authoritative refreshed offer")
	_expect(screen_scene.contains("RightInspector.tscn") 		and screen_scene.contains("PlayerBoard.tscn") 		and not screen_scene.contains("PlayerRoster.tscn"), "narrow scope retains existing V0.6 table shell")
	_expect(projection_source.contains("FORBIDDEN_KEYS") \
		and projection_source.contains("future_track_sequence") \
		and projection_source.contains("rival_commodity_inventory") \
		and projection_source.contains("rng_state"), "projection contract explicitly rejects future, rival-private, and RNG fields")

	screen.queue_free()
	await process_frame
	_finish()


func _has_nodes(root_node: Node, names: Array[String]) -> bool:
	if root_node == null:
		return false
	for node_name in names:
		if root_node.find_child(node_name, true, false) == null:
			return false
	return true


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_PLAYER_CARD_DOCK_PRODUCTION_CUTOVER_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04_PLAYER_CARD_DOCK_PRODUCTION_CUTOVER_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
