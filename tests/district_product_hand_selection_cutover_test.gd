extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const PORT_SCENE := preload("res://scenes/runtime/TableSelectionIntentPort.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")

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
var _refreshes: Array[Dictionary] = []


class BlockingForcedDecisionPort:
	extends ForcedDecisionResponsePort

	var blocked := false

	func blocks_ordinary_gameplay(_viewer_index: int) -> bool:
		return blocked


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	_test_contract()
	_test_typed_targets_and_actor_separation()
	_test_fail_closed()
	_test_exact_once_and_forced_decision()
	_test_detached_snapshot_contract()
	_test_card_supply_reconciliation()
	await _test_ui_typed_emission()
	_test_source_negative_gates()
	print("DistrictProductHandSelectionCutover: %d checks / %d failures" % [_checks, _failures])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		_player(0, false, 1200, 2),
		_player(1, true, 900, 3),
		_player(2, true, 800, 1),
		_player(3, true, 700, 2),
	]
	_world.districts = [
		{"id": "region-0", "region_id": "region-0", "name": "North Ring", "products": ["星露莓"], "destroyed": false},
		{"id": "region-1", "region_id": "region-1", "name": "South Ring", "products": ["环晶电池"], "destroyed": false},
		{"id": "region-2", "region_id": "region-2", "name": "Outer Ring", "products": ["重力陶瓷"], "destroyed": false},
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
	_session.set("_session_id", "session-target-selection-1")
	_session.set("_scenario_id", "standard")
	_session.set("_seed", 23)
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
	_port.presentation_refresh_requested.connect(
		func(kind: StringName, reason: StringName) -> void:
			_refreshes.append({"kind": kind, "reason": reason})
	)


func _test_contract() -> void:
	var debug := _port.debug_snapshot()
	var kinds: Array = debug.get("supported_selection_kinds", []) if debug.get("supported_selection_kinds", []) is Array else []
	for kind in [TableSelectionIntent.KIND_SELECT_DISTRICT, TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT, TableSelectionIntent.KIND_SELECT_HAND_SLOT]:
		_expect(kinds.has(kind), "%s is a first-class typed table-selection intent" % str(kind))
	_expect(not bool(debug.get("owns_selection_state", true)) and not bool(debug.get("references_main", true)), "typed target port coordinates the existing owner without Main fallback")
	_expect(_identity.public_district_exists(0) and _identity.public_district_exists(2), "district authorization reads the public world projection")
	_expect(_identity.authorized_player_hand_slot_exists(0, 1), "local viewer can validate an existing own hand slot")
	_expect(not _identity.authorized_player_hand_slot_exists(0, 2), "local viewer hand validation fails closed outside its slot range")


func _test_typed_targets_and_actor_separation() -> void:
	var world_before := _world.to_save_data()
	var session_before := _session.session_summary()
	var actor_before := _actor_index()
	var inspected_before := _selection.inspected_player_index()
	var product_id := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])

	var product := _port.submit_intent(_product_intent("target:product", product_id, &"qa_driver"))
	_expect(product.accepted and product.changed and _selection.selected_trade_product == product_id, "typed product intent changes only the gameplay target product")
	_expect(product.presentation_refresh_mask == [&"map"] and _last_refresh_reason() == &"selected_trade_product_changed", "product selection requests one map refresh")
	var hand := _port.submit_intent(_hand_intent("target:hand", 1, &"qa_driver"))
	_expect(hand.accepted and hand.changed and _selection.selected_hand_slot == 1, "typed hand intent selects one authorized local hand slot")
	_expect(hand.presentation_refresh_mask == [&"full"] and _last_refresh_reason() == &"selected_hand_slot_changed", "hand selection requests one full refresh")
	var district := _port.submit_intent(_district_intent("target:district", 2, &"qa_driver"))
	_expect(district.accepted and district.changed and _selection.selected_district == 2, "typed district intent selects one public district")
	_expect(district.previous_hand_slot == 1 and district.hand_slot == -1 and _selection.selected_hand_slot == -1, "district selection atomically clears stale hand focus")
	_expect(_selection.selected_trade_product == product_id, "district selection preserves the independently selected product target")
	_expect(district.presentation_refresh_mask == [&"full"] and _last_refresh_reason() == &"selected_district_changed", "district selection requests one full refresh")
	_expect(_actor_index() == actor_before and _selection.inspected_player_index() == inspected_before, "district, product, and hand targets never alter actor or inspected-player identity")
	_expect(_world.to_save_data() == world_before and _session.session_summary() == session_before, "accepted target selection has zero gameplay-world and session mutation")
	var receipt_data := district.to_dictionary()
	_expect(TablePresentationPureDataPolicy.is_pure_data(receipt_data), "typed selection receipt is detached pure data")
	_expect(not _contains_any(receipt_data.keys(), ["cash", "hand", "private_inventory", "hidden_owner", "ai_plan"]), "typed selection receipt exposes no private hand contents or hidden authority")


func _test_fail_closed() -> void:
	var before := _selection.snapshot()
	_expect(_reason(_district_intent("reject:district", 99, &"qa_driver")) == "target_district_missing", "missing district target fails closed")
	_expect(_reason(_product_intent("reject:product", "not-a-public-product", &"qa_driver")) == "target_trade_product_missing", "unknown product target fails closed")
	_expect(_reason(_hand_intent("reject:hand", 99, &"qa_driver")) == "target_hand_slot_missing", "missing local hand slot fails closed")
	var wrong_viewer := _hand_intent("reject:viewer", 0, &"qa_driver")
	wrong_viewer.viewer_index = 1
	_expect(_reason(wrong_viewer) == "identity_wrong_viewer", "opponent viewer cannot probe or select another hand")
	var stale := _district_intent("reject:stale", 1, &"qa_driver")
	stale.expected_selection_revision -= 1
	_expect(_reason(stale) == "selection_revision_stale", "stale selection revision fails closed")
	var bad_district_source := _district_intent("reject:district-source", 1, &"qa_driver")
	bad_district_source.source_surface = &"player_board"
	_expect(str(bad_district_source.validation_report().get("reason_code", "")) == "source_surface_invalid", "district intent uses a strict source allowlist")
	var bad_product_source := _product_intent("reject:product-source", "", &"qa_driver")
	bad_product_source.source_surface = &"hand_rack"
	_expect(str(bad_product_source.validation_report().get("reason_code", "")) == "source_surface_invalid", "product intent uses a strict source allowlist")
	var bad_hand_source := _hand_intent("reject:hand-source", 0, &"qa_driver")
	bad_hand_source.source_surface = &"planet_map"
	_expect(str(bad_hand_source.validation_report().get("reason_code", "")) == "source_surface_invalid", "hand intent uses a strict source allowlist")
	_expect(_selection.snapshot() == before, "all rejected targets leave the complete selection state unchanged")


func _test_exact_once_and_forced_decision() -> void:
	var request := _district_intent("exact:district", 1, &"qa_driver")
	var first := _port.submit_intent(request)
	var revision_after_first := int(_selection.snapshot().get("revision", -1))
	_expect(first.accepted, "first stable district request applies")
	var replay := _port.submit_intent(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay", "same target request cannot apply twice")
	_expect(int(_selection.snapshot().get("revision", -1)) == revision_after_first, "target replay leaves selection revision unchanged")
	var collision := _product_intent("exact:district", str(ProductMarketRuntimeController.PRODUCT_CATALOG[1]), &"qa_driver")
	var collision_receipt := _port.submit_intent(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision, "same request ID with another target payload fails as a collision")

	_forced_port.blocked = true
	var blocked_request := _hand_intent("forced:hand", 0, &"qa_driver")
	var blocked_before := _selection.snapshot()
	var blocked := _port.submit_intent(blocked_request)
	_expect(not blocked.accepted and blocked.reason_code == "forced_decision_blocks_selection", "forced decision blocks an ordinary hand target change")
	_expect(_selection.snapshot() == blocked_before, "forced-decision rejection leaves all target fields unchanged")
	_forced_port.blocked = false
	_expect(_port.submit_intent(blocked_request).accepted, "forced-decision rejection does not poison the exact-once journal")


func _test_detached_snapshot_contract() -> void:
	var normalized: Dictionary = TableSnapshot.new().apply_dictionary({
		"selection_context": {
			"revision": 41,
			"selected_district": 2,
			"district_count": 3,
			"selected_trade_product": "星露莓",
			"trade_product_ids": ["星露莓", "环晶电池"],
			"default_trade_product_id": "环晶电池",
			"selected_hand_slot": 1,
			"hand_slot_count": 2,
			"private_hand": ["forbidden"],
		},
	}).to_ui_dictionary()
	var context: Dictionary = normalized.get("selection_context", {})
	_expect(int(context.get("revision", -1)) == 41 and int(context.get("district_count", -1)) == 3, "UI receives detached target bounds and selection revision")
	_expect(context.get("trade_product_ids", []) == ["星露莓", "环晶电池"] and int(context.get("hand_slot_count", -1)) == 2, "UI receives only public product IDs and own hand slot count")
	_expect(not context.has("private_hand") and TablePresentationPureDataPolicy.is_pure_data(normalized), "snapshot drops private hand contents and remains pure data")


func _test_card_supply_reconciliation() -> void:
	var presentation := TableCardSupplyPresentationState.new()
	presentation.selected_market_skill = "stale-card"
	presentation.previewed_district_card = "other-stale-card"
	var first := presentation.reconcile_district_card_choices(["card-a", "card-b", "card-a", ""])
	_expect(bool(first.get("changed", false)) and presentation.selected_market_skill == "card-a" and presentation.previewed_district_card == "card-a", "district change reconciles stale card focus to the first public supply choice")
	presentation.previewed_district_card = "card-b"
	presentation.reconcile_district_card_choices(["card-a", "card-b"])
	_expect(presentation.selected_market_skill == "card-a" and presentation.previewed_district_card == "card-b", "valid selected and previewed supply cards remain stable")
	presentation.reconcile_district_card_choices([])
	_expect(presentation.selected_market_skill.is_empty() and presentation.previewed_district_card.is_empty(), "district without public supply clears both card presentation targets")
	presentation.free()


func _test_ui_typed_emission() -> void:
	var screen := GAME_SCREEN_SCENE.instantiate() as SpaceSyndicateGameScreen
	_host.add_child(screen)
	screen.bind_presentation_viewer(0, _authorization.context().authorization_revision)
	screen.bind_gameplay_actor_authorization_context(_identity.current_actor_context(&"game_screen"))
	screen.apply_state({
		"selection_context": {
			"revision": int(_selection.snapshot().get("revision", -1)),
			"selected_district": _selection.selected_district,
			"district_count": _world.districts.size(),
			"selected_trade_product": _selection.selected_trade_product,
			"trade_product_ids": ProductMarketRuntimeController.PRODUCT_CATALOG.duplicate(),
			"default_trade_product_id": str(ProductMarketRuntimeController.PRODUCT_CATALOG[0]),
			"selected_hand_slot": _selection.selected_hand_slot,
			"hand_slot_count": 2,
		},
	})
	var intents: Array[TableSelectionIntent] = []
	screen.table_selection_intent_requested.connect(func(intent: TableSelectionIntent) -> void: intents.append(intent))
	_expect(screen.request_district_selection(2, &"planet_map"), "GameScreen accepts an allowlisted typed district request")
	_expect(screen.request_trade_product_selection(str(ProductMarketRuntimeController.PRODUCT_CATALOG[0]), &"player_board"), "GameScreen accepts an allowlisted typed product request")
	_expect(screen.request_hand_selection(1, &"hand_rack"), "GameScreen accepts an allowlisted typed hand request")
	_expect(intents.size() == 3, "three UI requests emit exactly three typed intents and zero generic actions")
	_expect(intents[0].selection_kind == TableSelectionIntent.KIND_SELECT_DISTRICT and intents[0].target_district_index == 2, "district UI request carries only its stable district index")
	_expect(intents[1].selection_kind == TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT and intents[1].target_trade_product_id == str(ProductMarketRuntimeController.PRODUCT_CATALOG[0]), "product UI request carries only its public product ID")
	_expect(intents[2].selection_kind == TableSelectionIntent.KIND_SELECT_HAND_SLOT and intents[2].target_hand_slot == 1, "hand UI request carries only its slot index, not card contents")
	_expect(not screen.request_hand_selection(0, &"planet_map"), "GameScreen rejects a hand request from a district surface")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_E
	var before_hotkey := intents.size()
	_expect(bool(screen.call("_handle_table_selection_hotkey", key_event)) and intents.size() == before_hotkey + 1, "district cycling hotkey uses the same typed request path")
	_expect(intents.back().source_surface == &"keyboard_hotkey" and intents.back().selection_kind == TableSelectionIntent.KIND_SELECT_DISTRICT, "hotkey adapter cannot bypass typed district authorization")
	await process_frame
	screen.queue_free()


func _test_source_negative_gates() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for legacy_method in ["\nfunc _select_district(", "\nfunc _cycle_district(", "\nfunc _cycle_trade_product(", "\nfunc _on_runtime_game_screen_card_selected("]:
		_expect(not main_source.contains(legacy_method), "%s is physically absent from Main" % legacy_method)
	for assignment in ["table_selection_state().selected_district =", "table_selection_state().selected_trade_product =", "table_selection_state().selected_hand_slot ="]:
		_expect(not main_source.contains(assignment), "Main has no direct %s write" % assignment.trim_suffix(" ="))
	_expect(not main_source.contains("select_trade_product_target("), "Main routes player-facing product target changes through the typed intent port")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(screen_source.contains("request_district_selection") and screen_source.contains("request_trade_product_selection") and screen_source.contains("request_hand_selection"), "GameScreen exposes the three narrow typed target adapters")
	_expect(not screen_source.contains("call(\"_select_district\"") and not screen_source.contains("Main._select_district"), "GameScreen target selection has no dynamic Main fallback")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(coordinator_source.contains("reason == &\"selected_district_changed\"") and coordinator_source.contains("reconcile_district_card_choices"), "scene-owned coordinator preserves district card preview reconciliation")
	var optional_route_source := FileAccess.get_file_as_string("res://scripts/runtime/optional_route_presentation_runtime_service.gd")
	_expect(optional_route_source.contains("selected_trade_product_id"), "optional-route public filtering remains a distinct presentation-only owner")
	_expect(int(_port.debug_snapshot().get("gameplay_mutation_count", -1)) == 0, "typed target port reports zero gameplay mutation")


func _district_intent(request_id: String, district_index: int, source_surface: StringName) -> TableSelectionIntent:
	var intent := _base_intent(request_id, TableSelectionIntent.KIND_SELECT_DISTRICT, source_surface)
	intent.target_district_index = district_index
	return intent


func _product_intent(request_id: String, product_id: String, source_surface: StringName) -> TableSelectionIntent:
	var intent := _base_intent(request_id, TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT, source_surface)
	intent.target_trade_product_id = product_id
	return intent


func _hand_intent(request_id: String, slot_index: int, source_surface: StringName) -> TableSelectionIntent:
	var intent := _base_intent(request_id, TableSelectionIntent.KIND_SELECT_HAND_SLOT, source_surface)
	intent.target_hand_slot = slot_index
	return intent


func _base_intent(request_id: String, kind: StringName, source_surface: StringName) -> TableSelectionIntent:
	_request_revision += 1
	var intent := TableSelectionIntent.new()
	intent.request_id = request_id
	intent.selection_kind = kind
	intent.viewer_index = 0
	intent.authorization_revision = _authorization.context().authorization_revision
	intent.session_id = str(_session.session_summary().get("session_id", ""))
	intent.session_revision = _session.session_start_revision()
	intent.expected_selection_revision = int(_selection.snapshot().get("revision", -1))
	intent.source_surface = source_surface
	intent.request_revision = _request_revision
	return intent


func _player(index: int, is_ai: bool, cash: int, slot_count: int) -> Dictionary:
	var slots: Array = []
	for slot_index in range(slot_count):
		slots.append({"name": "private-card-%d-%d" % [index, slot_index]})
	return {
		"id": "player-%d" % index,
		"name": "Local Player" if index == 0 else "AI %d" % index,
		"is_ai": is_ai,
		"seat_type": "ai" if is_ai else "human",
		"role_name": "Public Role %d" % index,
		"cash": cash,
		"slots": slots,
		"city_guesses": {},
		"eliminated": false,
	}


func _actor_index() -> int:
	var context := _identity.current_actor_context(&"qa_driver")
	return context.authorized_actor_player_index if context.is_valid() else -1


func _last_refresh_reason() -> StringName:
	return _refreshes.back().get("reason", &"") if not _refreshes.is_empty() else &""


func _reason(intent: TableSelectionIntent) -> String:
	return _port.submit_intent(intent).reason_code


func _contains_any(values: Array, candidates: Array) -> bool:
	for candidate in candidates:
		if values.has(candidate):
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
		return
	_failures += 1
	push_error("[FAIL] %s" % label)
