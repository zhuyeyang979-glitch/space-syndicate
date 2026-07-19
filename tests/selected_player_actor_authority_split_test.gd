extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const PORT_SCENE := preload("res://scenes/runtime/TableSelectionIntentPort.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

var _checks := 0
var _failures := 0
var _request_revision := 0
var _host: Node
var _world: WorldSessionState
var _authorization: LocalViewerAuthorization
var _session: GameSessionRuntimeController
var _identity: PlayerIdentityAuthorizationBoundary
var _selection: TableSelectionState
var _forced_port: BlockingForcedDecisionPort
var _port: TableSelectionIntentPort


class BlockingForcedDecisionPort:
	extends ForcedDecisionResponsePort

	var blocked := false

	func blocks_ordinary_gameplay(_viewer_index: int) -> bool:
		return blocked


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	_test_authority_contract()
	_test_actor_and_inspection_separation()
	_test_forgery_and_revisions()
	_test_exact_once()
	_test_forced_decision_and_zero_mutation()
	await _test_ui_input_and_presentation_sync()
	_test_source_negative_gates()
	print("SelectedPlayerActorAuthoritySplit: %d checks / %d failures" % [_checks, _failures])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		_player(0, false, 1200),
		_player(1, true, 900),
		_player(2, true, 800),
		_player(3, true, 700),
	]
	_world.districts = [
		{"id": "region-0", "name": "North Ring", "products": ["Energy"]},
		{"id": "region-1", "name": "South Ring", "products": ["Food"]},
	]
	_authorization = LocalViewerAuthorization.new()
	_authorization.name = "Authorization"
	_host.add_child(_authorization)
	_authorization.configure(_world)
	_session = GameSessionRuntimeController.new()
	_session.name = "GameSession"
	_host.add_child(_session)
	_session.set("_configured", true)
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	_session.set("_session_id", "session-player-inspection-1")
	_session.set("_scenario_id", "standard")
	_session.set("_seed", 17)
	_identity = IDENTITY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	_identity.name = "Identity"
	_identity.local_viewer_authorization_path = NodePath("../Authorization")
	_identity.world_session_state_path = NodePath("../World")
	_identity.game_session_path = NodePath("../GameSession")
	_host.add_child(_identity)
	_selection = TableSelectionState.new()
	_selection.name = "Selection"
	_host.add_child(_selection)
	_forced_port = BlockingForcedDecisionPort.new()
	_forced_port.name = "ForcedPort"
	_host.add_child(_forced_port)
	_port = PORT_SCENE.instantiate() as TableSelectionIntentPort
	_port.name = "SelectionPort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.selection_state_path = NodePath("../Selection")
	_port.forced_decision_response_port_path = NodePath("../ForcedPort")
	_host.add_child(_port)


func _test_authority_contract() -> void:
	var context := _identity.current_actor_context(&"qa_driver")
	_expect(context.is_valid(), "current session issues one valid gameplay actor context")
	_expect(context.viewer_index == 0 and context.authorized_actor_player_index == 0, "viewer zero is authorized to act only as player zero")
	_expect(context.session_id == "session-player-inspection-1" and context.session_revision == _session.session_start_revision(), "actor context binds the active session identity and revision")
	_expect(context.authorization_revision == _authorization.context().authorization_revision, "actor context binds the viewer authorization revision")
	var detached := GameplayActorAuthorizationContext.from_dictionary(context.to_dictionary())
	_expect(detached.is_valid() and detached.fingerprint() == context.fingerprint(), "actor context has a stable detached pure-data copy")
	_expect(TablePresentationPureDataPolicy.is_pure_data(context.to_dictionary()), "actor context satisfies the pure-data policy")
	var context_keys := context.to_dictionary().keys()
	_expect(not _contains_any(context_keys, ["selected_player", "target_player", "cash", "hand", "hidden_owner", "ai_plan"]), "actor context contains no selection, target, or private player payload")
	var debug := _identity.debug_snapshot()
	_expect(str(debug.get("actor_authority", "")) == "LocalViewerAuthorization+GameSessionRuntimeController+WorldSessionState", "existing identity boundary documents the three-owner actor authority")
	_expect(not bool(debug.get("infers_actor_from_ui", true)) and not bool(debug.get("owns_gameplay_state", true)), "actor authority neither trusts UI nor owns gameplay state")


func _test_actor_and_inspection_separation() -> void:
	_expect(_selection.inspected_player_index() == 0 and _actor_index() == 0, "viewer zero starts with actor zero and inspected player zero")
	var first := _port.submit_intent(_inspection_intent("inspect:player-2", 2, &"player_seat"))
	_expect(first.accepted and first.applied and first.changed, "player-seat inspection selects player two through the typed port")
	_expect(_selection.inspected_player_index() == 2 and _selection.selected_player == 2, "legacy selected_player now mirrors only the inspected player target")
	_expect(_actor_index() == 0, "inspecting player two does not change the authorized actor")
	var second := _port.submit_intent(_inspection_intent("inspect:player-3", 3, &"table_toolbar"))
	_expect(second.accepted and _selection.inspected_player_index() == 3, "toolbar inspection can select player three")
	_expect(_actor_index() == 0, "inspecting player three does not change the authorized actor")
	var own := _port.submit_intent(_inspection_intent("inspect:player-0", 0, &"keyboard_hotkey"))
	_expect(own.accepted and _selection.inspected_player_index() == 0, "keyboard inspection can return to player zero")
	_expect(_actor_index() == 0, "returning inspection to self leaves actor authority unchanged")
	var receipt_data := first.to_dictionary()
	_expect(not receipt_data.has("authorized_actor_player_index"), "public selection receipt does not expose actor authority")
	_expect(not _contains_any(receipt_data.keys(), ["cash", "hand", "private_inventory", "hidden_owner", "ai_plan"]), "selection receipt contains no private player fields")


func _test_forgery_and_revisions() -> void:
	var forged := _identity.authorize_actor_index(2, &"qa_driver")
	_expect(not forged.is_valid() and forged.reason_code == "actor_authority_mismatch", "viewer zero cannot forge actor player two")
	_selection.select_inspected_player(2, int(_selection.snapshot().get("revision", -1)))
	var selected_forgery := _identity.authorize_actor_index(_selection.inspected_player_index(), &"player_seat")
	_expect(not selected_forgery.is_valid() and selected_forgery.reason_code == "actor_authority_mismatch", "inspected player two cannot authorize actor player two")
	var wrong_viewer := _inspection_intent("inspect:wrong-viewer", 1, &"qa_driver")
	wrong_viewer.viewer_index = 1
	_expect(_reason(wrong_viewer) == "identity_wrong_viewer", "wrong viewer fails closed")
	var stale_authorization := _inspection_intent("inspect:stale-auth", 1, &"qa_driver")
	stale_authorization.authorization_revision += 1
	_expect(_reason(stale_authorization) == "identity_authorization_revision_stale", "stale authorization revision fails closed")
	var wrong_session := _inspection_intent("inspect:wrong-session", 1, &"qa_driver")
	wrong_session.session_id = "session-forged"
	_expect(_reason(wrong_session) == "identity_wrong_session", "wrong session ID fails closed")
	var stale_session := _inspection_intent("inspect:stale-session", 1, &"qa_driver")
	stale_session.session_revision += 1
	_expect(_reason(stale_session) == "identity_session_revision_stale", "stale session revision fails closed")
	var stale_selection := _inspection_intent("inspect:stale-selection", 1, &"qa_driver")
	stale_selection.expected_selection_revision -= 1
	_expect(_reason(stale_selection) == "selection_revision_stale", "stale selection revision fails closed")
	var missing_player := _inspection_intent("inspect:missing-player", 99, &"qa_driver")
	_expect(_reason(missing_player) == "target_player_missing", "missing public player target fails closed")
	var invalid_source := _inspection_intent("inspect:bad-source", 1, &"qa_driver")
	invalid_source.source_surface = &"planet_map"
	_expect(str(invalid_source.validation_report().get("reason_code", "")) == "source_surface_invalid", "inspection source uses a strict allowlist")
	for source_surface in TableSelectionIntent.PLAYER_INSPECTION_SOURCE_SURFACES:
		var source_context := _identity.current_actor_context(source_surface)
		_expect(source_context.is_valid() and source_context.authorized_actor_player_index == 0, "%s cannot alter actor authority" % str(source_surface))
	var identity_source := FileAccess.get_file_as_string("res://scripts/runtime/player_identity_authorization_boundary.gd")
	_expect(not identity_source.contains("player_color") and not identity_source.contains("PlayerSeat"), "player color and PlayerSeat nodes cannot authorize an actor")


func _test_exact_once() -> void:
	var request := _inspection_intent("inspect:replay", 3, &"fullscreen_hud")
	var first := _port.submit_intent(request)
	var revision_after_first := int(_selection.snapshot().get("revision", -1))
	_expect(first.accepted and _selection.inspected_player_index() == 3, "first stable inspection request applies")
	var replay := _port.submit_intent(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay", "same inspection request is idempotently rejected on replay")
	_expect(int(_selection.snapshot().get("revision", -1)) == revision_after_first, "request replay does not apply selection twice")
	var collision := _inspection_intent("inspect:replay", 1, &"fullscreen_hud")
	var collision_receipt := _port.submit_intent(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision and collision_receipt.reason_code == "request_id_collision", "same request ID with a different inspection target is rejected")
	_expect(_selection.inspected_player_index() == 3, "request collision leaves inspection unchanged")


func _test_forced_decision_and_zero_mutation() -> void:
	var world_before := _world.to_save_data()
	var session_before := _session.session_summary()
	var selection_before := _selection.snapshot()
	var actor_before := _actor_index()
	var cash_before := _cash_values()
	_forced_port.blocked = true
	var blocked_request := _inspection_intent("inspect:forced-block", 1, &"player_board")
	var blocked := _port.submit_intent(blocked_request)
	_expect(not blocked.accepted and blocked.reason_code == "forced_decision_blocks_selection", "blocking forced decision rejects player inspection")
	_expect(_selection.snapshot() == selection_before, "forced-decision rejection leaves all table selection fields unchanged")
	_expect(_actor_index() == actor_before, "forced-decision rejection leaves actor authority unchanged")
	_expect(_world.to_save_data() == world_before and _session.session_summary() == session_before, "inspection rejection does not mutate world or session state")
	_expect(_cash_values() == cash_before, "inspection rejection does not mutate player cash")
	_forced_port.blocked = false
	var retry := _port.submit_intent(blocked_request)
	_expect(retry.accepted and _selection.inspected_player_index() == 1, "a forced-decision rejection does not poison the exact-once journal")
	var other_selection_before := _selection.snapshot()
	var other_world_before := _world.to_save_data()
	var accepted := _port.submit_intent(_inspection_intent("inspect:zero-mutation", 2, &"qa_driver"))
	var other_selection_after := _selection.snapshot()
	_expect(accepted.accepted and _world.to_save_data() == other_world_before, "accepted inspection has zero gameplay-world mutation")
	for key in ["selected_district", "selected_trade_product", "selected_card_resolution_id", "selected_hand_slot", "selected_map_layer_focus"]:
		_expect(other_selection_after.get(key) == other_selection_before.get(key), "%s remains unchanged by player inspection" % key)
	_expect(int(_port.debug_snapshot().get("gameplay_mutation_count", -1)) == 0, "selection port reports zero gameplay mutation")


func _test_ui_input_and_presentation_sync() -> void:
	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	_host.add_child(screen)
	var actor_context := _identity.current_actor_context(&"game_screen")
	screen.bind_presentation_viewer(0, _authorization.context().authorization_revision)
	screen.bind_gameplay_actor_authorization_context(actor_context)
	screen.apply_state({
		"selection_context": {"revision": int(_selection.snapshot().get("revision", -1))},
		"planet": {"public_player_seat_sources": _public_seat_sources()},
		"top_bar": {"identity": "Local Player"},
		"player_board": {"identity": "Local Player"},
	})
	var emitted_intents: Array[TableSelectionIntent] = []
	var emitted_receipts: Array[TableSelectionReceipt] = []
	screen.table_selection_intent_requested.connect(func(intent: TableSelectionIntent) -> void: emitted_intents.append(intent))
	screen.table_selection_intent_requested.connect(_port.submit_intent)
	_port.receipt_ready.connect(func(receipt: TableSelectionReceipt) -> void: emitted_receipts.append(receipt))
	_port.receipt_ready.connect(screen.apply_table_selection_receipt)
	await process_frame
	var seat_host := screen.find_child("RoleSeatLayerHost", true, false) as RoleSeatLayerHost
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	seat_host.call("_on_seat_gui_input", mouse_event, 2)
	_expect(not emitted_intents.is_empty() and emitted_intents.back().source_surface == &"player_seat", "PlayerSeat click emits the typed inspection intent")
	_expect(_selection.inspected_player_index() == 2 and _actor_index() == 0, "PlayerSeat click changes inspection without changing actor")
	var debug := screen.player_inspection_debug_snapshot()
	_expect(bool(debug.get("player_seat_synced", false)), "PlayerSeat inspection outline follows the authoritative receipt")
	_expect(bool(debug.get("player_board_synced", false)), "PlayerBoard public identity follows the authoritative receipt")
	_expect(bool(debug.get("toolbar_synced", false)), "table toolbar public identity follows the authoritative receipt")
	_expect(bool(debug.get("fullscreen_hud_synced", false)), "fullscreen HUD metadata follows the authoritative receipt")
	_expect(bool(debug.get("right_inspector_public_only", false)), "RightInspector uses the public-player context only")
	var apply_count_before_replay := int(debug.get("receipt_apply_count", -1))
	screen.apply_table_selection_receipt(emitted_receipts.back())
	_expect(int(screen.player_inspection_debug_snapshot().get("receipt_apply_count", -1)) == apply_count_before_replay, "duplicate receipt revision does not apply presentation targets twice")
	var seat_layout := seat_host.layout_debug_snapshot()
	_expect(_inspected_count(seat_layout) == 1 and _inspected_index(seat_layout) == 2, "exactly one public PlayerSeat displays the inspection outline")
	var player_board := screen.player_board as SpaceSyndicatePlayerBoard
	player_board.call("_on_identity_chip_gui_input", mouse_event)
	_expect(emitted_intents.back().source_surface == &"player_board" and _selection.inspected_player_index() == 0, "PlayerBoard identity click uses the same typed path")
	var top_bar := screen.top_bar as SpaceSyndicateTopBar
	top_bar.call("_on_identity_chip_gui_input", mouse_event)
	_expect(emitted_intents.back().source_surface == &"table_toolbar" and _selection.inspected_player_index() == 0, "toolbar identity click uses the same typed path")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_4
	key_event.unicode = 52
	var key_target := int(screen.call("_player_inspection_index_for_key", key_event))
	var before_keyboard_count := emitted_intents.size()
	screen.request_player_inspection(key_target, &"keyboard_hotkey")
	_expect(key_target == 3 and emitted_intents.size() == before_keyboard_count + 1 and _selection.inspected_player_index() == 3, "keyboard 1-8 adapter is equivalent to the click intent path")
	var gamepad_event := InputEventAction.new()
	gamepad_event.action = &"ui_accept"
	gamepad_event.pressed = true
	seat_host.call("_on_seat_gui_input", gamepad_event, 1)
	_expect(emitted_intents.back().source_surface == &"player_seat" and _selection.inspected_player_index() == 1, "gamepad focus acceptance uses the PlayerSeat typed path")
	var fullscreen_before := emitted_intents.size()
	screen.request_player_inspection(2, &"fullscreen_hud")
	_expect(emitted_intents.size() == fullscreen_before + 1 and emitted_intents.back().source_surface == &"fullscreen_hud", "fullscreen HUD adapter emits one allowlisted inspection intent")
	var text_input := LineEdit.new()
	screen.add_child(text_input)
	text_input.grab_focus()
	await process_frame
	_expect(bool(screen.call("_should_ignore_player_inspection_hotkey")), "text input focus suppresses player inspection hotkeys")
	text_input.release_focus()
	text_input.queue_free()
	var right_inspector := screen.right_inspector as SpaceSyndicateRightInspector
	var public_text := _visible_text(right_inspector)
	_expect(public_text.contains("AI 2") and not public_text.contains("700") and not public_text.contains("secret-card"), "opponent inspection shows public identity without cash or hand data")
	_port.receipt_ready.disconnect(screen.apply_table_selection_receipt)
	screen.queue_free()


func _test_source_negative_gates() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("func _select_player") and not main_source.contains("table_selection_state().selected_player"), "Main has zero selected-player route or actor reads")
	_expect(not main_source.contains("_set_selected_player_card_group_ready") and main_source.contains("_set_authorized_player_card_group_ready"), "card-group readiness names and resolves the authorized actor")
	var card_submission := FileAccess.get_file_as_string("res://scripts/runtime/card_play_submission_runtime_controller.gd")
	var military := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	var monster := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var ai := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(not card_submission.contains("request.get(\"player_index\", _table_selection_state.selected_player"), "card submission requires an explicit actor index")
	_expect(not military.contains("selection.selected_player"), "military commands require an explicit acting player")
	_expect(not monster.contains("player_index = selected_player") and not monster.contains("else selected_player"), "monster commands and wagers have no selected-player actor fallback")
	_expect(not ai.contains("_skill_play_requirement_status(selected_player") and not ai.contains("selected_player = player_index"), "AI card decisions use their explicit player index")
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(not game_screen_source.contains("Main._select_player") and not game_screen_source.contains("call(\"_select_player\""), "selected-player UI has no dynamic Main fallback")
	var coordinator_scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_expect(coordinator_scene.count("PlayerIdentityAuthorizationBoundary.tscn") == 1 and coordinator_scene.count("TableSelectionIntentPort.tscn") == 1, "scene composition has one actor authority boundary and one selection intent port")
	_expect(FileAccess.get_file_as_string("res://scripts/runtime/table_selection_state.gd").contains("presentation_inspection_target"), "legacy selected_player semantics are frozen as presentation inspection")


func _inspection_intent(request_id: String, target_player_index: int, source_surface: StringName) -> TableSelectionIntent:
	_request_revision += 1
	var intent := TableSelectionIntent.new()
	intent.request_id = request_id
	intent.selection_kind = TableSelectionIntent.KIND_INSPECT_PLAYER
	intent.viewer_index = 0
	intent.authorization_revision = _authorization.context().authorization_revision
	intent.session_id = str(_session.session_summary().get("session_id", ""))
	intent.session_revision = _session.session_start_revision()
	intent.expected_selection_revision = int(_selection.snapshot().get("revision", -1))
	intent.target_player_index = target_player_index
	intent.source_surface = source_surface
	intent.request_revision = _request_revision
	return intent


func _player(index: int, is_ai: bool, cash: int) -> Dictionary:
	return {
		"id": "player-%d" % index,
		"name": "Local Player" if index == 0 else "AI %d" % index,
		"is_ai": is_ai,
		"seat_type": "ai" if is_ai else "human",
		"role_name": "Public Role %d" % index,
		"cash": cash,
		"slots": [{"name": "secret-card-%d" % index}],
		"city_guesses": {},
		"eliminated": false,
	}


func _public_seat_sources() -> Array:
	var result: Array = []
	for index in range(_world.players.size()):
		result.append({
			"player_index": index,
			"public_player_name": "Local Player" if index == 0 else "AI %d" % index,
			"role_name": "Public Role %d" % index,
			"player_color": Color.from_hsv(float(index) / 4.0, 0.5, 0.9),
			"is_local_player": index == 0,
			"public_status": "ready",
		})
	return result


func _actor_index() -> int:
	var context := _identity.current_actor_context(&"qa_driver")
	return context.authorized_actor_player_index if context.is_valid() else -1


func _cash_values() -> Array:
	var result: Array = []
	for player_variant in _world.players:
		result.append(int((player_variant as Dictionary).get("cash", -1)))
	return result


func _reason(intent: TableSelectionIntent) -> String:
	return _port.submit_intent(intent).reason_code


func _contains_any(values: Array, candidates: Array) -> bool:
	for candidate in candidates:
		if values.has(candidate):
			return true
	return false


func _inspected_count(layout: Dictionary) -> int:
	var count := 0
	for seat_variant in layout.get("seats", []):
		if seat_variant is Dictionary and bool((seat_variant as Dictionary).get("inspected", false)):
			count += 1
	return count


func _inspected_index(layout: Dictionary) -> int:
	for seat_variant in layout.get("seats", []):
		if seat_variant is Dictionary and bool((seat_variant as Dictionary).get("inspected", false)):
			return int((seat_variant as Dictionary).get("player_index", -1))
	return -1


func _visible_text(node: Node) -> String:
	if node == null:
		return ""
	var values: Array[String] = []
	_collect_visible_text(node, values)
	return "\n".join(values)


func _collect_visible_text(node: Node, values: Array[String]) -> void:
	if node is Label and (node as Label).visible:
		values.append((node as Label).text)
	elif node is RichTextLabel and (node as RichTextLabel).visible:
		values.append((node as RichTextLabel).text)
	elif node is Button and (node as Button).visible:
		values.append((node as Button).text)
	for child in node.get_children():
		_collect_visible_text(child, values)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
		return
	_failures += 1
	push_error("[FAIL] %s" % label)
