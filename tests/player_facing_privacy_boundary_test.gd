extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/player_facing_privacy_boundary.save"

const AI_CASH_SENTINEL := 987654321
const HUMAN_CASH_SENTINEL := 4321
const AI_HAND_SENTINEL := "AI_PRIVATE_HAND_SENTINEL"
const AI_DISCARD_SENTINEL := "AI_PRIVATE_DISCARD_SENTINEL"
const AI_PLAN_SENTINEL := "AI_PRIVATE_PLAN_SENTINEL"
const HIDDEN_OWNER_SENTINEL := "AI_HIDDEN_OWNER_SENTINEL"

const AI_STARTER_PRIVATE_KEYS := [
	"starter_monster_index",
	"starter_monster_name",
	"starter_monster_card",
	"monster_label",
	"starter_note",
]

const PUBLIC_PRIVATE_KEYS := [
	"player_cash",
	"counted_hand_size",
	"hand_limit",
	"can_buy",
	"purchase_window",
	"hand_cards",
	"player_hand",
	"private_discard",
	"discard_card",
	"discard_card_name",
	"hidden_owner",
	"hidden_owner_id",
	"owner_truth",
	"ai_plan",
	"ai_score",
	"utility_scores",
	"decision_samples",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "QA save-path override exists before tree entry")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.free()
		_finish()
		return
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "focused gate uses only the isolated QA save path")

	root.size = Vector2i(1600, 960)
	root.add_child(main)
	await _wait_frames(8)
	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	main.call("_open_new_game_setup_menu")
	await _wait_frames(3)

	var setup_variant: Variant = main.call("_new_game_setup_page_snapshot")
	var setup: Dictionary = setup_variant if setup_variant is Dictionary else {}
	var seats: Array = setup.get("seats", []) if setup.get("seats", []) is Array else []
	_expect(seats.size() == 3, "real setup snapshot contains one human and two AI seats")
	var starter_names := _configured_starter_names(main)
	_check_setup_snapshot(seats, starter_names)
	_check_setup_controls(main, starter_names)

	main.call("_on_new_game_setup_action_requested", "setup_start")
	# This privacy gate needs the production start path, not a running economy clock.
	# Freeze before the first post-start frame so unrelated CommodityFlow work stays out of scope.
	main.set("time_scale", 0.0)
	await _wait_frames(10)
	var players: Array = ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players if ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players is Array else []
	_expect(players.size() == 3, "real setup_start creates three production players")
	if players.size() == 3:
		await _check_district_supply_boundary(main, players)

	_stop_audio(main)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(2)
	_finish()


func _check_setup_snapshot(seats: Array, starter_names: Array[String]) -> void:
	if seats.size() != 3 or starter_names.size() != 3:
		return
	var human: Dictionary = seats[0] if seats[0] is Dictionary else {}
	_expect(str(human.get("seat_type", "")) == "human", "seat zero is the local human presentation")
	_expect(str(human.get("monster_label", "")) == starter_names[0], "local human sees the selected starter label")
	_expect(human.has("starter_note"), "local human retains the selected starter summary")
	var human_faces: Array = human.get("card_faces", []) if human.get("card_faces", []) is Array else []
	_expect(human_faces.size() >= 2, "local human retains public role plus own starter card face")

	for seat_index in [1, 2]:
		var ai_seat: Dictionary = seats[seat_index] if seats[seat_index] is Dictionary else {}
		var private_key_paths: Array[String] = []
		_collect_key_paths(ai_seat, AI_STARTER_PRIVATE_KEYS, "seat[%d]" % seat_index, private_key_paths)
		var ai_text := _value_text(ai_seat)
		_expect(str(ai_seat.get("seat_type", "")) == "ai", "seat %d is marked AI using a public seat type" % seat_index)
		_expect(private_key_paths.is_empty(), "AI seat %d recursively omits starter-specific keys: %s" % [seat_index, private_key_paths])
		_expect(not ai_text.contains(starter_names[seat_index]), "AI seat %d recursively omits its actual starter name" % seat_index)
		_expect(ai_text.contains("随机分配/开局后未知"), "AI seat %d carries only the fixed unknown-starter wording" % seat_index)
		var faces: Array = ai_seat.get("card_faces", []) if ai_seat.get("card_faces", []) is Array else []
		_expect(faces.size() == 1 and not _value_text(faces).contains("monster_card"), "AI seat %d publishes the role face without a starter card face" % seat_index)


func _check_setup_controls(main: Node, starter_names: Array[String]) -> void:
	var page := main.find_child("NewGameSetupPage", true, false)
	_expect(page != null and page is CanvasItem and (page as CanvasItem).is_visible_in_tree(), "real NewGameSetupPage is visible")
	if page == null:
		return
	var visible_text := _visible_control_text(page)
	_expect(visible_text.contains("随机分配/开局后未知"), "AI seat controls render the fixed public unknown-starter wording")
	for seat_index in [1, 2]:
		_expect(not visible_text.contains(starter_names[seat_index]), "visible setup controls omit AI seat %d's actual starter" % seat_index)
	_expect(visible_text.contains(starter_names[0]), "visible setup controls preserve the local human starter choice")


func _check_district_supply_boundary(main: Node, players: Array) -> void:
	var human: Dictionary = players[0] if players[0] is Dictionary else {}
	var ai: Dictionary = players[1] if players[1] is Dictionary else {}
	human["cash"] = HUMAN_CASH_SENTINEL
	ai["cash"] = AI_CASH_SENTINEL
	ai["slots"] = [
		{"name": "%s_0" % AI_HAND_SENTINEL, "kind": "private_test"},
		{"name": "%s_1" % AI_HAND_SENTINEL, "kind": "private_test"},
		{"name": "%s_2" % AI_HAND_SENTINEL, "kind": "private_test"},
		{"name": "%s_3" % AI_HAND_SENTINEL, "kind": "private_test"},
	]
	ai["private_discard"] = [AI_DISCARD_SENTINEL]
	ai["ai_plan"] = AI_PLAN_SENTINEL
	ai["ai_score"] = 246813579
	ai["hidden_owner"] = HIDDEN_OWNER_SENTINEL
	players[0] = human
	players[1] = ai
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	_expect(coordinator != null, "production Coordinator remains composed")
	if coordinator == null:
		return
	coordinator.world_session_state().players = players
	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort
	var presentation := coordinator.card_supply_presentation_state()
	_expect(query != null and presentation != null, "scene-owned DistrictSupplyViewerQueryPort is the only drawer query source")
	if query == null or presentation == null:
		return

	var district_index := _first_public_supply_district(coordinator, query, presentation)
	_expect(district_index >= 0, "public district path exposes at least one card without requiring an AI monster")
	if district_index < 0:
		return

	var public_sources := [
		{"name": "missing_viewer", "source": _district_supply_surface(query, presentation, district_index, 1, -1)},
		{"name": "opponent_subject", "source": _district_supply_surface(query, presentation, district_index, 1, 0)},
		{"name": "ai_self_forgery", "source": _district_supply_surface(query, presentation, district_index, 1, 1)},
		{"name": "unknown_viewer", "source": _district_supply_surface(query, presentation, district_index, 0, 999)},
	]
	for case_variant in public_sources:
		var case: Dictionary = case_variant as Dictionary
		var source: Dictionary = case.get("source", {}) if case.get("source", {}) is Dictionary else {}
		_check_public_supply_source(str(case.get("name", "public")), source)

	var opponent_surface: Dictionary = public_sources[1].get("source", {}) as Dictionary
	var public_output: Dictionary = opponent_surface.get("snapshot", {}) if opponent_surface.get("snapshot", {}) is Dictionary else {}
	var public_cards: Array = public_output.get("cards", []) if public_output.get("cards", []) is Array else []
	_expect(not public_output.is_empty() and not public_cards.is_empty(), "typed public query composes a non-empty browseable card list")
	var public_output_private_paths: Array[String] = []
	_collect_key_paths(public_output, ["player_cash", "counted_hand_size", "hand_limit", "purchase_window"], "public_output", public_output_private_paths)
	_expect(public_output_private_paths.is_empty(), "composed public snapshot omits private aggregate/window keys: %s" % [public_output_private_paths])
	_expect(_sentinel_leaks(public_output).is_empty(), "composed public snapshot has zero recursive sentinel leaks")
	var public_debug := query.debug_snapshot()
	_expect(bool(public_debug.get("configured", false)) and not bool(public_debug.get("references_main", true)) and not bool(public_debug.get("mutates_gameplay", true)), "typed query remains configured, read-only, and independent from Main")

	var own_surface := _district_supply_surface(query, presentation, district_index, 0, 0)
	var own_source: Dictionary = own_surface.get("snapshot", {}) if own_surface.get("snapshot", {}) is Dictionary else {}
	var expected_hand := int(main.call("_player_counted_hand_size", human))
	var own_text := _value_text(own_source)
	_expect(str(own_surface.get("visibility_scope", "")) == "viewer_private" and str(own_source.get("visibility_scope", "")) == "viewer_private", "local human self-view receives viewer_private scope")
	_expect(own_text.contains("¥%d" % HUMAN_CASH_SENTINEL), "local human self-view preserves exact own cash in the formatted drawer")
	_expect(own_text.contains("手牌 %d/" % expected_hand), "local human self-view preserves its own hand aggregate")
	var own_cards: Array = own_source.get("cards", []) if own_source.get("cards", []) is Array else []
	var eligibility_present := not own_cards.is_empty()
	for card_variant in own_cards:
		if not (card_variant is Dictionary):
			eligibility_present = false
			continue
		var card := card_variant as Dictionary
		eligibility_present = eligibility_present and card.has("actionable") and card.has("state_text")
	_expect(eligibility_present, "local human card rows retain private purchase eligibility state")

	var screen := main.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var viewer_context := coordinator.get_node("TablePresentationQueryPorts").viewer_context() as TablePresentationViewerContext
	_expect(overlay != null, "real typed district supply target exists")
	if overlay != null:
		_expect(overlay.apply_district_supply_presentation(opponent_surface, 0, viewer_context.authorization_revision), "typed target accepts the public browse surface")
		await _wait_frames(2)
		var drawer := screen.get_district_supply_drawer()
		var public_drawer_text := _visible_control_text(drawer)
		_expect(not public_drawer_text.contains("¥%d" % AI_CASH_SENTINEL), "public opponent drawer omits exact rival cash")
		_expect(overlay.apply_district_supply_presentation(own_surface, 0, viewer_context.authorization_revision), "typed target accepts the authorized local surface")
		await _wait_frames(2)
		var drawer_text := _visible_control_text(drawer)
		_expect(drawer_text.contains("¥%d" % HUMAN_CASH_SENTINEL), "normal local-human drawer still renders own exact cash")
		var visible_leaks := _text_leaks(drawer_text, [])
		_expect(visible_leaks.is_empty(), "visible district controls contain no injected AI sentinel leak: %s" % [visible_leaks])


func _first_public_supply_district(
	coordinator: GameRuntimeCoordinator,
	query: DistrictSupplyViewerQueryPort,
	presentation: TableCardSupplyPresentationState
) -> int:
	var districts: Array = coordinator.world_session_state().districts
	for district_index in range(districts.size()):
		var surface := _district_supply_surface(query, presentation, district_index, 1, 0)
		var snapshot: Dictionary = surface.get("snapshot", {}) if surface.get("snapshot", {}) is Dictionary else {}
		var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
		if not cards.is_empty():
			return district_index
	return -1


func _district_supply_surface(
	query: DistrictSupplyViewerQueryPort,
	presentation: TableCardSupplyPresentationState,
	district_index: int,
	subject_index: int,
	viewer_index: int
) -> Dictionary:
	presentation.open_district = district_index
	presentation.open_player = subject_index
	return query.snapshot_for_viewer(viewer_index)


func _check_public_supply_source(case_name: String, source: Dictionary) -> void:
	_expect(not source.is_empty(), "%s returns a fail-closed public surface instead of private data" % case_name)
	_expect(str(source.get("visibility_scope", "")) == "public", "%s is explicitly public" % case_name)
	var private_paths: Array[String] = []
	_collect_key_paths(source, PUBLIC_PRIVATE_KEYS, case_name, private_paths)
	_expect(private_paths.is_empty(), "%s recursively omits private aggregate/owner/AI keys: %s" % [case_name, private_paths])
	_expect(_sentinel_leaks(source).is_empty(), "%s has zero recursive sentinel leaks" % case_name)
	var snapshot: Dictionary = source.get("snapshot", {}) if source.get("snapshot", {}) is Dictionary else {}
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	_expect(not cards.is_empty(), "%s keeps the public card list viewable" % case_name)
	var browse_states_valid := not cards.is_empty()
	for card_variant in cards:
		if not (card_variant is Dictionary):
			browse_states_valid = false
			continue
		var card := card_variant as Dictionary
		var preview: Dictionary = card.get("preview", {}) if card.get("preview", {}) is Dictionary else {}
		browse_states_valid = browse_states_valid \
			and str(card.get("state_text", "")) == "仅浏览" \
			and not bool(card.get("actionable", true)) \
			and not bool(preview.get("buy_enabled", true))
	_expect(browse_states_valid, "%s exposes only public price plus fixed non-actionable browse states" % case_name)


func _configured_starter_names(main: Node) -> Array[String]:
	var result: Array[String] = []
	for index in [0, 1, 2]:
		var entry_variant: Variant = main.call("_catalog_entry", index)
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		result.append(str(entry.get("name", "missing_starter_%d" % index)))
	return result


func _collect_key_paths(value: Variant, forbidden_keys: Array, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if forbidden_keys.has(key.to_lower()):
				result.append(child_path)
			_collect_key_paths((value as Dictionary).get(key_variant), forbidden_keys, child_path, result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_key_paths((value as Array)[index], forbidden_keys, "%s[%d]" % [path, index], result)


func _sentinel_leaks(value: Variant) -> Array[String]:
	var text := _value_text(value)
	var leaks: Array[String] = []
	for sentinel in [str(AI_CASH_SENTINEL), AI_HAND_SENTINEL, AI_DISCARD_SENTINEL, AI_PLAN_SENTINEL, HIDDEN_OWNER_SENTINEL, "246813579"]:
		if text.contains(sentinel):
			leaks.append(sentinel)
	return leaks


func _text_leaks(text: String, starter_names: Array[String]) -> Array[String]:
	var leaks: Array[String] = []
	for sentinel in [str(AI_CASH_SENTINEL), AI_HAND_SENTINEL, AI_DISCARD_SENTINEL, AI_PLAN_SENTINEL, HIDDEN_OWNER_SENTINEL, "246813579"]:
		if text.contains(sentinel):
			leaks.append(sentinel)
	for seat_index in [1, 2]:
		if seat_index < starter_names.size() and text.contains(starter_names[seat_index]):
			leaks.append(starter_names[seat_index])
	return leaks


func _value_text(value: Variant) -> String:
	var parts: Array[String] = []
	_collect_value_text(value, parts)
	return "\n".join(parts)


func _collect_value_text(value: Variant, parts: Array[String]) -> void:
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			_collect_value_text((value as Dictionary).get(key_variant), parts)
	elif value is Array:
		for item_variant: Variant in value:
			_collect_value_text(item_variant, parts)
	elif value is String or value is StringName or value is int or value is float:
		parts.append(str(value))


func _visible_control_text(node: Node) -> String:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is RichTextLabel:
		parts.append((node as RichTextLabel).text)
	elif node is Button:
		parts.append((node as Button).text)
	elif node is LineEdit:
		parts.append((node as LineEdit).text)
		parts.append((node as LineEdit).placeholder_text)
	if node is Control:
		parts.append((node as Control).tooltip_text)
	for child in node.get_children():
		parts.append(_visible_control_text(child))
	return "\n".join(parts)


func _stop_audio(node: Node) -> void:
	for audio_variant in node.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_variant as AudioStreamPlayer
		if audio != null:
			audio.stop()
			audio.stream = null


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("PLAYER_FACING_PRIVACY_BOUNDARY_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLAYER_FACING_PRIVACY_BOUNDARY_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	if not _failures.is_empty():
		print("PLAYER_FACING_PRIVACY_BOUNDARY_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
