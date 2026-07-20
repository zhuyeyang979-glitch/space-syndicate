extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const PORT_SCENE := preload("res://scenes/runtime/TableSelectionIntentPort.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const HISTORY_SCENE := preload("res://scenes/runtime/CardResolutionHistoryRuntimeService.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const PRODUCTION_SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")

var _checks := 0
var _failures: Array[String] = []
var _request_revision := 0
var _host: Node
var _world: WorldSessionState
var _authorization: LocalViewerAuthorization
var _session: GameSessionRuntimeController
var _identity: PlayerIdentityAuthorizationBoundary
var _selection: TableSelectionState
var _forced_port: BlockingForcedDecisionPort
var _queue: CardResolutionQueueRuntimeService
var _history: CardResolutionHistoryRuntimeService
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
	_test_scene_and_contract()
	_test_public_queue_focus()
	_test_public_history_focus()
	_test_private_target_is_not_used_for_focus()
	_test_fail_closed_and_exact_once()
	await _test_game_screen_typed_adapters()
	_test_explicit_card_effect_context()
	_test_source_negative_gates()
	await _test_formal_main_composition()
	print("PublicCardTrackFocusSelectionCutover: %d checks / %d failures" % [_checks, _failures.size()])
	_host.free()
	quit(0 if _failures.is_empty() else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		_player(0, false),
		_player(1, true),
		_player(2, true),
		_player(3, true),
	]
	_world.districts = [
		{"id": "region-0", "region_id": "region-0", "name": "North Ring", "destroyed": false},
		{"id": "region-1", "region_id": "region-1", "name": "South Ring", "destroyed": false},
		{"id": "region-2", "region_id": "region-2", "name": "Outer Ring", "destroyed": false},
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
	_session.set("_session_id", "session-card-track-focus-1")
	_session.set("_scenario_id", "standard")
	_session.set("_seed", 73)
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
	_queue = QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	_queue.name = "Queue"
	_host.add_child(_queue)
	_queue.replace_state({
		"current_queue": [
			_entry(51, "route_shield", "route_insurance", 1),
			_entry(52, "hidden_target", "monster_bound_action", -1).merged({"target_slot": 2, "private_target": "SECRET_MONSTER"}, true),
		],
		"active_entry": {},
		"next_queue": [],
		"resolution_sequence": 52,
		"last_group_window_sequence": 1,
	})
	_history = HISTORY_SCENE.instantiate() as CardResolutionHistoryRuntimeService
	_history.name = "History"
	_host.add_child(_history)
	_history.configure({"history_limit": 8})
	_expect(bool(_history.append_resolved(_entry(61, "public_contract", "area_trade_contract", 0).merged({
		"resolved": true,
		"resolution_outcome": "resolved",
		"contract_source_district": 0,
		"contract_target_district": 2,
		"hidden_owner": "SECRET_OWNER",
	}, true)).get("appended", false)), "public history fixture appends")
	_port = PORT_SCENE.instantiate() as TableSelectionIntentPort
	_port.name = "SelectionPort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.selection_state_path = NodePath("../Selection")
	_port.forced_decision_response_port_path = NodePath("../ForcedPort")
	_port.card_resolution_queue_path = NodePath("../Queue")
	_port.card_resolution_history_path = NodePath("../History")
	_host.add_child(_port)


func _test_scene_and_contract() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(scene_source.count("[node name=\"TableSelectionIntentPort\"") == 1, "runtime composition keeps one typed selection port")
	_expect(scene_source.contains("card_resolution_queue_path = NodePath(\"../CardResolutionQueueRuntimeService\")"), "selection port explicitly binds the queue public source")
	_expect(scene_source.contains("card_resolution_history_path = NodePath(\"../CardResolutionHistoryRuntimeService\")"), "selection port explicitly binds the history public source")
	var kinds: Array = _port.debug_snapshot().get("supported_selection_kinds", [])
	_expect(kinds.has(TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION), "card-resolution focus is a first-class typed selection kind")
	for source_surface in TableSelectionIntent.CARD_RESOLUTION_SELECTION_SOURCE_SURFACES:
		_expect(PlayerIdentityActionRequest.SOURCE_SURFACES.has(source_surface), "shared identity envelope authorizes card-focus source %s" % str(source_surface))
	_expect(not bool(_port.debug_snapshot().get("owns_selection_state", true)) and not bool(_port.debug_snapshot().get("references_main", true)), "typed focus port coordinates the existing owner without Main fallback")


func _test_public_queue_focus() -> void:
	var world_before := _world.to_save_data()
	var session_before := _session.session_summary()
	var queue_before := _queue.capture_runtime_checkpoint()
	var history_before := _history.to_save_data()
	var actor_before := _selection.selected_player
	var inspected_before := _selection.inspected_player_index()
	var before_revision := int(_selection.snapshot().get("revision", -1))
	var receipt := _port.submit_intent(_focus_intent("focus:queue", 51, &"qa_driver"))
	_expect(receipt.accepted and receipt.changed and receipt.card_resolution_id == 51, "typed public queue focus selects the stable resolution ID")
	_expect(receipt.district_index == 1 and receipt.focus_district_index == 1 and _selection.selected_district == 1, "public selected_district focuses the matching region atomically")
	_expect(receipt.selection_revision_after == before_revision + 1, "resolution and district focus advance one shared selection revision")
	_expect(_selection.selected_player == actor_before and _selection.inspected_player_index() == inspected_before, "public card focus never changes actor or inspected player")
	_expect(_world.to_save_data() == world_before and _session.session_summary() == session_before, "public card focus mutates no gameplay world or session state")
	_expect(_queue.capture_runtime_checkpoint() == queue_before and _history.to_save_data() == history_before, "public card focus mutates neither queue nor history owner")
	var receipt_text := JSON.stringify(receipt.to_dictionary())
	_expect(TablePresentationPureDataPolicy.is_pure_data(receipt.to_dictionary()), "focus receipt is detached pure data")
	for forbidden_key in ["target_slot", "private_target", "hidden_owner", "player_index", "cash", "hand", "ai_plan"]:
		_expect(not _contains_key_recursive(receipt.to_dictionary(), forbidden_key), "focus receipt omits exact field %s" % forbidden_key)
	for sentinel in ["SECRET_MONSTER", "SECRET_OWNER"]:
		_expect(not receipt_text.contains(sentinel), "focus receipt omits sentinel %s" % sentinel)


func _test_public_history_focus() -> void:
	var receipt := _port.submit_intent(_focus_intent("focus:history", 61, &"qa_driver"))
	_expect(receipt.accepted and receipt.card_resolution_id == 61, "resolved public history remains a legal focus target")
	_expect(receipt.focus_district_index == 2 and _selection.selected_district == 2, "public contract target is the preferred history map focus")


func _test_private_target_is_not_used_for_focus() -> void:
	var district_before := _selection.selected_district
	var receipt := _port.submit_intent(_focus_intent("focus:hidden-target", 52, &"qa_driver"))
	_expect(receipt.accepted and receipt.card_resolution_id == 52, "an existing public resolution remains selectable without a public district")
	_expect(receipt.focus_district_index == -1 and receipt.district_index == district_before and _selection.selected_district == district_before, "private target_slot cannot move the public map focus")
	var clear := _port.submit_intent(_focus_intent("focus:clear", -1, &"qa_driver"))
	_expect(clear.accepted and clear.card_resolution_id == -1 and _selection.selected_card_resolution_id == -1, "typed clear removes card focus without changing district")
	_expect(clear.focus_district_index == -1 and _selection.selected_district == district_before, "clearing card focus preserves the current region")


func _test_fail_closed_and_exact_once() -> void:
	var before := _selection.snapshot()
	_expect(_port.submit_intent(_focus_intent("reject:missing", 999, &"qa_driver")).reason_code == "target_card_resolution_missing", "unknown public resolution fails closed")
	var wrong_viewer := _focus_intent("reject:viewer", 51, &"qa_driver")
	wrong_viewer.viewer_index = 1
	_expect(_port.submit_intent(wrong_viewer).reason_code == "identity_wrong_viewer", "opponent viewer cannot mutate local public focus")
	var stale := _focus_intent("reject:stale", 51, &"qa_driver")
	stale.expected_selection_revision -= 1
	_expect(_port.submit_intent(stale).reason_code == "selection_revision_stale", "stale selection focus fails closed")
	var invalid_source := _focus_intent("reject:surface", 51, &"qa_driver")
	invalid_source.source_surface = &"hand_rack"
	_expect(str(invalid_source.validation_report().get("reason_code", "")) == "source_surface_invalid", "card focus uses a strict public-surface allowlist")
	_forced_port.blocked = true
	var forced := _focus_intent("reject:forced", 51, &"qa_driver")
	_expect(_port.submit_intent(forced).reason_code == "forced_decision_blocks_selection", "forced decision blocks ordinary public focus")
	_forced_port.blocked = false
	_expect(_selection.snapshot() == before, "all rejected focus requests leave complete selection state unchanged")
	var exact := _focus_intent("focus:exact", 51, &"qa_driver")
	var first := _port.submit_intent(exact)
	var revision_after_first := int(_selection.snapshot().get("revision", -1))
	var replay := _port.submit_intent(exact)
	_expect(first.accepted and not replay.accepted and replay.idempotent_replay, "stable focus request applies exactly once")
	_expect(int(_selection.snapshot().get("revision", -1)) == revision_after_first, "focus replay cannot advance selection revision")
	var collision := _focus_intent("focus:exact", 61, &"qa_driver")
	var collision_receipt := _port.submit_intent(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision, "same ID with another resolution fails as collision")


func _test_game_screen_typed_adapters() -> void:
	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	_host.add_child(screen)
	screen.bind_presentation_viewer(0, _authorization.context().authorization_revision)
	screen.bind_gameplay_actor_authorization_context(_identity.current_actor_context(&"game_screen"))
	screen.apply_state({
		"selection_context": {
			"revision": int(_selection.snapshot().get("revision", -1)),
			"selected_district": _selection.selected_district,
			"selected_card_resolution_id": -1,
		},
	})
	var intents: Array[TableSelectionIntent] = []
	var raw_actions := [0]
	screen.table_selection_intent_requested.connect(func(intent: TableSelectionIntent) -> void: intents.append(intent))
	screen.action_requested.connect(func(_action_id: String) -> void: raw_actions[0] = int(raw_actions[0]) + 1)
	screen.call("_on_action_requested", "track_select_51")
	_expect(intents.size() == 1 and int(raw_actions[0]) == 0, "RightInspector track selection emits one typed intent and zero generic actions")
	_expect(intents.back().selection_kind == TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION and intents.back().target_card_resolution_id == 51 and intents.back().source_surface == &"right_inspector", "RightInspector adapter carries only stable public resolution identity")
	screen.call("_on_public_bid_action_requested", "track_select_52")
	_expect(intents.size() == 2 and int(raw_actions[0]) == 0 and intents.back().source_surface == &"public_bid_board", "public bid link uses the same typed focus boundary")
	screen.call("_on_track_action_requested", "track_select_61")
	_expect(intents.size() == 3 and int(raw_actions[0]) == 0 and intents.back().source_surface == &"card_resolution_track", "card track link uses the same typed focus boundary")
	screen.call("_on_action_requested", "track_select_invalid")
	_expect(intents.size() == 3 and int(raw_actions[0]) == 0, "malformed track selection fails closed without falling through to Main")
	screen.call("_on_track_action_requested", "track_open_public_contract")
	_expect(int(raw_actions[0]) == 1, "track detail navigation remains a distinct generic route for its existing Compendium adapter")
	await process_frame
	screen.queue_free()


func _test_explicit_card_effect_context() -> void:
	var submission_source := FileAccess.get_file_as_string("res://scripts/runtime/card_play_submission_runtime_controller.gd")
	_expect(submission_source.contains("int(request.get(\"selected_card_resolution_id\", -1))"), "card submission accepts an explicit resolution target")
	_expect(submission_source.contains("\"selected_card_resolution_id\": int(frozen_context.get(\"selected_card_resolution_id\", -1))") and submission_source.contains("\"stable_target_envelope\": stable_target_envelope.duplicate(true)"), "queued resolution freezes the explicit target for later effect execution")
	var intel_source := FileAccess.get_file_as_string("res://scripts/runtime/card_intel_runtime_service.gd")
	_expect(not intel_source.contains("TableSelectionState") and not intel_source.contains("_table_selection_state"), "Intel effect resolution never reads mutable UI focus")
	_expect(intel_source.contains("context.get(\"selected_card_resolution_id\", -1)"), "Intel effects consume only the frozen resolution context")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(not ai_source.contains("var selected_card_resolution_id") and not ai_source.contains("_table_selection_state"), "AI no longer reads or writes the human card-track focus")
	_expect(ai_source.contains("_traceable_contract_entries(-1, 1)") and ai_source.contains("context[\"selected_card_resolution_id\"]"), "AI chooses a public trace target explicitly before submitting the card")


func _test_source_negative_gates() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for retired in [
		"\nfunc _select_card_resolution_track_entry(",
		"\nfunc _focus_card_resolution_track_entry(",
		"\nfunc _focus_card_resolution_target_region(",
		"\nfunc _card_resolution_public_target_district(",
		"action_id.begins_with(\"track_return_\")",
		"action_id.begins_with(\"track_select_\")",
	]:
		_expect(not main_source.contains(retired), "%s is physically absent from Main" % retired.strip_edges())
	_expect(not main_source.contains("selected_card_resolution_id ="), "Main has zero direct selected-card-resolution writes")
	_expect(main_source.contains("\nfunc _card_resolution_entry_by_id("), "shared authoritative card entry lookup remains for real gameplay consumers")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not coordinator_source.contains("\nfunc select_card_resolution("), "coordinator exposes no untyped resolution setter")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/table_selection_intent_port.gd")
	_expect(port_source.contains("queue.public_snapshot()") and port_source.contains("history.public_history_snapshot()"), "focus authorization reads only public queue and history projections")
	_expect(not port_source.contains(".entry_by_id(") and not port_source.contains(".history_snapshot(") and not port_source.contains("target_slot"), "focus authorization cannot read private queue/history targeting fields")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(screen_source.contains("request_card_resolution_selection") and screen_source.contains("KIND_SELECT_CARD_RESOLUTION"), "GameScreen owns one narrow typed public-focus adapter")
	_expect(not screen_source.contains("Main._select_card_resolution") and not screen_source.contains("call(\"_select_card_resolution"), "GameScreen has no dynamic Main fallback")


func _test_formal_main_composition() -> void:
	var start_result: Dictionary = await PRODUCTION_SESSION_START_DRIVER.start_default_session(
		self,
		"user://test_runs/public_card_track_focus_selection_cutover.save",
		"public-card-track-focus-formal-main"
	)
	var main_root := start_result.get("main_root") as Node
	_expect(bool(start_result.get("started", false)), "formal main.tscn starts a four-player session through SessionStartTransaction")
	_expect(int(start_result.get("main_start_call_count", -1)) == 0 and int(start_result.get("setup_fallback_count", -1)) == 0, "formal product fixture uses no retired Main start path")
	if main_root == null or not bool(start_result.get("started", false)):
		if main_root != null:
			main_root.queue_free()
			await process_frame
		return
	for _frame in range(6):
		await process_frame
	main_root.process_mode = Node.PROCESS_MODE_DISABLED
	var coordinator := start_result.get("coordinator") as GameRuntimeCoordinator
	var formal_queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService if coordinator != null else null
	var formal_selection := coordinator.table_selection_state() if coordinator != null else null
	var formal_port := coordinator.get_node_or_null("TableSelectionIntentPort") as TableSelectionIntentPort if coordinator != null else null
	var game_screen := main_root.get_node_or_null("RuntimeGameScreen") as SpaceSyndicateGameScreen
	_expect(formal_queue != null and formal_selection != null and formal_port != null and game_screen != null, "formal main composition exposes one queue, selection owner, typed port, and GameScreen")
	if formal_queue != null and formal_selection != null and formal_port != null and game_screen != null:
		formal_queue.replace_state({
			"current_queue": [_entry(901, "formal_public_focus", "route_insurance", 1)],
			"active_entry": {},
			"next_queue": [],
			"resolution_sequence": 901,
			"last_group_window_sequence": 1,
		})
		var world := coordinator.world_session_state()
		var world_before := world.to_save_data()
		var queue_before := formal_queue.capture_runtime_checkpoint()
		var port_before := formal_port.debug_snapshot()
		var formal_receipts: Array[TableSelectionReceipt] = []
		formal_port.receipt_ready.connect(func(receipt: TableSelectionReceipt) -> void: formal_receipts.append(receipt))
		var submitted := game_screen.request_card_resolution_selection(901, &"card_resolution_track")
		await process_frame
		var port_after := formal_port.debug_snapshot()
		var formal_receipt: TableSelectionReceipt = formal_receipts.back() if not formal_receipts.is_empty() else null
		var formal_receipt_data: Dictionary = formal_receipt.to_dictionary() if formal_receipt != null else {}
		var formal_applied := submitted and formal_selection.selected_card_resolution_id == 901 and formal_selection.selected_district == 1
		var formal_exact_once := int(port_after.get("submission_count", -1)) == int(port_before.get("submission_count", -1)) + 1 \
			and int(port_after.get("accepted_count", -1)) == int(port_before.get("accepted_count", -1)) + 1
		if not formal_applied or not formal_exact_once:
			print("FORMAL_FOCUS_DIAGNOSTIC|submitted=%s|selection=%s|before=%s|after=%s|receipt=%s" % [submitted, JSON.stringify(formal_selection.snapshot()), JSON.stringify(port_before), JSON.stringify(port_after), JSON.stringify(formal_receipt_data)])
		_expect(formal_applied, "formal GameScreen submits the public focus through the scene-wired typed port")
		_expect(formal_exact_once, "formal public focus is accepted exactly once")
		_expect(world.to_save_data() == world_before and formal_queue.capture_runtime_checkpoint() == queue_before, "formal public focus mutates neither gameplay world nor queue authority")
	main_root.queue_free()
	await process_frame


func _focus_intent(request_id: String, resolution_id: int, source_surface: StringName) -> TableSelectionIntent:
	_request_revision += 1
	var intent := TableSelectionIntent.new()
	intent.request_id = request_id
	intent.selection_kind = TableSelectionIntent.KIND_SELECT_CARD_RESOLUTION
	intent.viewer_index = 0
	intent.authorization_revision = _authorization.context().authorization_revision
	intent.session_id = str(_session.session_summary().get("session_id", ""))
	intent.session_revision = _session.session_start_revision()
	intent.expected_selection_revision = int(_selection.snapshot().get("revision", -1))
	intent.target_card_resolution_id = resolution_id
	intent.source_surface = source_surface
	intent.request_revision = _request_revision
	return intent


func _entry(resolution_id: int, card_name: String, card_kind: String, selected_district: int) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": 2,
		"slot_index": 4,
		"selected_district": selected_district,
		"skill": {"name": card_name, "display_name": card_name, "kind": card_kind, "rank": 1},
	}


func _player(index: int, is_ai: bool) -> Dictionary:
	return {
		"id": "player-%d" % index,
		"name": "Local Player" if index == 0 else "AI %d" % index,
		"is_ai": is_ai,
		"seat_type": "ai" if is_ai else "human",
		"slots": [{"name": "private-card-%d" % index}],
		"cash": 900 - index * 50,
	}


func _contains_key_recursive(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == target_key or _contains_key_recursive((value as Dictionary)[key_variant], target_key):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_key_recursive(child, target_key):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % message)
		return
	_failures.append(message)
	push_error("[FAIL] %s" % message)
