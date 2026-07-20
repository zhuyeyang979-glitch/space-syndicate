extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const PORT_SCENE := preload("res://scenes/runtime/TableSelectionIntentPort.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const TOOLBAR_SCENE := preload("res://scenes/ui/map/PlanetMapControlToolbar.tscn")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _authorization: LocalViewerAuthorization
var _session: GameSessionRuntimeController
var _identity: PlayerIdentityAuthorizationBoundary
var _selection: TableSelectionState
var _port: TableSelectionIntentPort


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	_test_scene_contract()
	_test_ui_typed_emission()
	_test_authorized_map_layer_selection()
	_test_layer_contract_and_zero_mutation()
	_test_fail_closed()
	_test_exact_once()
	_test_rejected_request_does_not_poison_journal()
	_test_journal_session_scope()
	_test_presentation_revision_contract()
	print("TableSelectionIntentPort: %d checks / %d failures" % [_checks, _failures])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		{"id": "player-0", "name": "本地玩家", "is_ai": false, "seat_type": "human"},
		{"id": "player-1", "name": "AI 1", "is_ai": true, "seat_type": "ai"},
		{"id": "player-2", "name": "AI 2", "is_ai": true, "seat_type": "ai"},
	]
	_world.districts = [{"id": "region-0", "name": "北环区"}]
	_authorization = LocalViewerAuthorization.new()
	_authorization.name = "Authorization"
	_host.add_child(_authorization)
	_authorization.configure(_world)
	_session = GameSessionRuntimeController.new()
	_session.name = "GameSession"
	_host.add_child(_session)
	_session.set("_configured", true)
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	_session.set("_session_id", "session-selection-1")
	_session.set("_scenario_id", "standard")
	_identity = IDENTITY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	_identity.name = "Identity"
	_identity.local_viewer_authorization_path = NodePath("../Authorization")
	_identity.world_session_state_path = NodePath("../World")
	_identity.game_session_path = NodePath("../GameSession")
	_host.add_child(_identity)
	_selection = TableSelectionState.new()
	_selection.name = "Selection"
	_host.add_child(_selection)
	_port = PORT_SCENE.instantiate() as TableSelectionIntentPort
	_port.name = "SelectionPort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.selection_state_path = NodePath("../Selection")
	_host.add_child(_port)


func _test_scene_contract() -> void:
	var source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_expect(source.count("TableSelectionIntentPort.tscn") == 1, "runtime coordinator composes one typed table-selection port scene")
	_expect(source.count("[node name=\"TableSelectionIntentPort\"") == 1, "runtime coordinator owns one table-selection intent port")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(coordinator_source.contains("game_screen.table_selection_intent_requested.connect(port.submit_intent)"), "coordinator connects the formal GameScreen typed intent directly to the scene-owned port")
	_expect(not coordinator_source.contains("Main.table_selection"), "typed table-selection wiring has no Main dependency")
	var debug := _port.debug_snapshot()
	_expect(bool(debug.get("typed_identity_envelope_required", false)) and bool(debug.get("exact_once", false)), "port requires typed identity and exact-once authorization")
	_expect(not bool(debug.get("owns_selection_state", true)) and not bool(debug.get("references_main", true)), "port coordinates the existing selection owner without root fallback")


func _test_ui_typed_emission() -> void:
	var toolbar := TOOLBAR_SCENE.instantiate() as PlanetMapControlToolbar
	_host.add_child(toolbar)
	toolbar.set_controls({
		"layers": _layer_entries(),
		"selected_layer_id": "all",
	})
	var dedicated := [0]
	var generic := [0]
	toolbar.map_layer_focus_requested.connect(func(_layer_id: String) -> void: dedicated[0] = int(dedicated[0]) + 1)
	toolbar.control_action_requested.connect(func(_action_id: String, _payload: Dictionary) -> void: generic[0] = int(generic[0]) + 1)
	toolbar.call("_emit_layer_focus", "city")
	_expect(int(dedicated[0]) == 1 and int(generic[0]) == 0, "map-layer button emits one dedicated intent source and zero generic Main actions")
	toolbar.set_selected_map_layer_focus("city")
	var toolbar_debug := toolbar.debug_snapshot()
	_expect(str(toolbar_debug.get("layer_status", "")).contains("city") and _selected_layer_id(toolbar_debug) == "city", "authoritative receipt can update both toolbar status and selected button")
	var toolbar_source := FileAccess.get_file_as_string("res://scripts/ui/map/planet_map_control_toolbar.gd")
	_expect(not toolbar_source.contains("_emit_control_action(\"map_layer_focus\""), "production toolbar no longer emits the legacy map_layer_focus string route")

	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	_host.add_child(screen)
	screen.bind_presentation_viewer(0, _authorization.context().authorization_revision)
	screen.apply_state({"selection_context": {"revision": _selection.snapshot().get("revision", 0)}})
	var intents: Array[TableSelectionIntent] = []
	var raw_actions := [0]
	screen.table_selection_intent_requested.connect(func(intent: TableSelectionIntent) -> void: intents.append(intent))
	screen.action_requested.connect(func(_action_id: String) -> void: raw_actions[0] = int(raw_actions[0]) + 1)
	screen.call("_on_map_layer_focus_requested", "product")
	_expect(intents.size() == 1 and int(raw_actions[0]) == 0, "GameScreen turns the map-layer UI event into one typed intent and no generic action")
	var intent := intents[0]
	_expect(intent.viewer_index == 0 and intent.authorization_revision == _authorization.context().authorization_revision, "typed UI intent binds the current presentation viewer authority")
	_expect(intent.expected_selection_revision == int(_selection.snapshot().get("revision", -1)) and intent.map_layer_id == &"product", "typed UI intent carries the detached selection revision and stable layer ID")
	var visual_receipt := TableSelectionReceipt.new()
	visual_receipt.accepted = true
	visual_receipt.effective_map_layer_id = &"product"
	var screen_toolbar := screen.get_node_or_null("OverlayLayer/RuntimeSurfaceLayer/FullscreenMapOverlay/FullscreenMapMargin/FullscreenMapRows/FullscreenMapToolbar/FullscreenMapActionHost/PlanetMapControlToolbar") as PlanetMapControlToolbar
	if screen_toolbar != null:
		screen_toolbar.set_controls({"layers": _layer_entries(), "selected_layer_id": "all"})
	screen.apply_table_selection_receipt(visual_receipt)
	var hud := screen.get_node_or_null("OverlayLayer/RuntimeSurfaceLayer/FullscreenMapOverlay/FullscreenMapMargin/FullscreenMapRows/FullscreenMapReadingHud/FullscreenMapHudMargin/FullscreenMapLayerHud/FullscreenMapLayerChip/ChipMargin/FullscreenMapLayerHudLabel") as Label
	_expect(hud != null and hud.text.contains("product"), "authoritative receipt updates the fullscreen map HUD without a Main callback")
	screen.queue_free()
	toolbar.queue_free()


func _test_authorized_map_layer_selection() -> void:
	var refreshes: Array[StringName] = []
	_port.presentation_refresh_requested.connect(func(kind: StringName, _reason: StringName) -> void: refreshes.append(kind), CONNECT_ONE_SHOT)
	var before := _selection.snapshot()
	var receipt := _port.submit_intent(_intent("selection:city", "city", 1))
	var after := _selection.snapshot()
	_expect(receipt.accepted and receipt.changed and receipt.reason_code == "selection_applied", "valid map-layer intent updates the existing TableSelectionState owner")
	_expect(_selection.selected_map_layer_focus == "city", "formal city layer remains a first-class selection value")
	_expect(receipt.selection_revision_after == receipt.selection_revision_before + 1 and int(after.get("revision", -1)) == int(before.get("revision", -1)) + 1, "selection revision advances exactly once")
	_expect(refreshes == [&"map"] and receipt.presentation_refresh_requested, "accepted selection requests exactly one map presentation refresh")


func _test_layer_contract_and_zero_mutation() -> void:
	var world_before := _world.to_save_data()
	var session_before := _session.session_summary()
	var selection_before := _selection.snapshot()
	var receipt := _port.submit_intent(_intent("selection:product", "product", 2))
	var selection_after := _selection.snapshot()
	_expect(receipt.accepted and _selection.selected_map_layer_focus == "product", "formal product layer no longer normalizes silently to all")
	_expect(_world.to_save_data() == world_before and _session.session_summary() == session_before, "presentation selection does not mutate world or game-session state")
	for key in ["selected_player", "inspected_player", "selected_district", "selected_trade_product", "selected_card_resolution_id", "selected_hand_slot"]:
		_expect(selection_after.get(key) == selection_before.get(key), "%s remains unchanged by a map-layer intent" % key)
	var unchanged := _port.submit_intent(_intent("selection:product-unchanged", "product", 3))
	_expect(unchanged.accepted and not unchanged.changed and not unchanged.presentation_refresh_requested, "reselecting the active layer is an authorized no-op without duplicate refresh")


func _test_fail_closed() -> void:
	var invalid := _intent("selection:invalid-layer", "secret", 4)
	_expect(_reason(invalid) == "map_layer_invalid", "unknown layer fails closed")
	var stale := _intent("selection:stale", "weather", 5)
	stale.expected_selection_revision -= 1
	var stale_receipt := _port.submit_intent(stale)
	_expect(stale_receipt.reason_code == "selection_revision_stale", "stale selection revision fails closed")
	_expect(str(stale_receipt.effective_map_layer_id) == _selection.selected_map_layer_focus, "rejected selection receipt restores the authoritative map-layer visual")
	var wrong_viewer := _intent("selection:wrong-viewer", "weather", 6)
	wrong_viewer.viewer_index = 1
	_expect(_reason(wrong_viewer) == "identity_wrong_viewer", "wrong viewer fails closed at the player identity boundary")
	var stale_authorization := _intent("selection:stale-authorization", "weather", 7)
	stale_authorization.authorization_revision += 1
	_expect(_reason(stale_authorization) == "identity_authorization_revision_stale", "stale viewer authorization fails closed")


func _test_exact_once() -> void:
	var request := _intent("selection:replay", "weather", 8)
	_expect(_port.submit_intent(request).accepted, "first stable table-selection intent is accepted")
	var replay := _port.submit_intent(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay", "accepted table-selection intent cannot replay")
	var collision := request
	collision = _intent("selection:replay", "monster", 9)
	var collision_receipt := _port.submit_intent(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision and collision_receipt.reason_code == "request_id_collision", "same request ID with different payload fails as a collision")


func _test_rejected_request_does_not_poison_journal() -> void:
	var request := _intent("selection:retry", "city", 10)
	request.expected_selection_revision -= 1
	_expect(_reason(request) == "selection_revision_stale", "rejected selection does not enter the exact-once journal")
	request.expected_selection_revision = int(_selection.snapshot().get("revision", -1))
	_expect(_port.submit_intent(request).accepted, "corrected selection may reuse an ID that never authorized")


func _test_journal_session_scope() -> void:
	var request_id := "selection:session-scoped"
	_expect(_port.submit_intent(_intent(request_id, "all", 11)).accepted, "request ID authorizes in the original session")
	_session.set("_session_id", "session-selection-2")
	_session.set("_seed", 84)
	_expect(_port.submit_intent(_intent(request_id, "intel", 12)).accepted, "request ID may be reused after the authoritative session changes")
	_session.set("_session_id", "session-selection-1")
	_session.set("_seed", 0)


func _test_presentation_revision_contract() -> void:
	var normalized: Dictionary = TableSnapshot.new().apply_dictionary({
		"selection_context": {"revision": 17, "private_hand": ["forbidden"]},
	}).to_ui_dictionary()
	var context: Dictionary = normalized.get("selection_context", {})
	_expect(context == {
		"revision": 17,
		"selected_district": -1,
		"district_count": 0,
		"selected_trade_product": "",
		"trade_product_ids": [],
		"default_trade_product_id": "",
		"selected_hand_slot": -1,
		"hand_slot_count": 0,
	}, "TableSnapshot allowlists detached public target context without private hand contents")
	_expect(TablePresentationPureDataPolicy.is_pure_data(normalized), "selection request context remains detached pure data")
	var debug := _port.debug_snapshot()
	_expect(int(debug.get("gameplay_mutation_count", -1)) == 0 and int(debug.get("refresh_emission_count", 0)) >= 5, "port reports zero gameplay mutation and explicit presentation refreshes")


func _intent(request_id: String, layer_id: String, revision: int) -> TableSelectionIntent:
	var intent := TableSelectionIntent.new()
	intent.request_id = request_id
	intent.selection_kind = TableSelectionIntent.KIND_MAP_LAYER
	intent.viewer_index = 0
	intent.authorization_revision = _authorization.context().authorization_revision
	intent.expected_selection_revision = int(_selection.snapshot().get("revision", -1))
	intent.map_layer_id = StringName(layer_id)
	intent.source_surface = &"planet_map"
	intent.request_revision = revision
	return intent


func _layer_entries() -> Array:
	var result: Array = []
	for layer_id in TableSelectionIntent.MAP_LAYER_IDS:
		result.append({
			"id": str(layer_id),
			"label": str(layer_id).left(1).to_upper(),
			"text": str(layer_id),
			"tip": "public layer",
			"accent": "#38bdf8",
		})
	return result


func _selected_layer_id(debug: Dictionary) -> String:
	var layers: Array = debug.get("rendered_layers", []) if debug.get("rendered_layers", []) is Array else []
	for layer_variant in layers:
		var layer: Dictionary = layer_variant if layer_variant is Dictionary else {}
		if bool(layer.get("selected", false)):
			return str(layer.get("id", ""))
	return ""


func _reason(intent: TableSelectionIntent) -> String:
	return _port.submit_intent(intent).reason_code


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
		return
	_failures += 1
	push_error("[FAIL] %s" % label)
