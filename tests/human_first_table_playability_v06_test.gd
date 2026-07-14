extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/human_first_table_playability_v06.save"
const FIXED_SEED := 60619
const FORBIDDEN_PUBLIC_KEYS := [
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"private_owner",
	"private_payload",
	"opponent_cash",
	"opponent_hand",
	"opponent_discard",
	"cash_ledger_cents",
	"available_cents",
	"counted_hand_size",
	"ordinary_hand_count",
	"private_hand",
	"discard_pile",
	"ai_memory",
	"ai_plan",
	"ai_private_plan",
	"private_plan",
	"route_plan",
	"decision_samples",
	"reasoning",
	"utility_scores",
]
const PRIVATE_VALUE_SENTINELS := [
	"987654321",
	"VS06_PRIVATE_HAND_SENTINEL",
	"VS06_TRUE_OWNER_SENTINEL",
	"VS06_AI_PLAN_SENTINEL",
]

var _checks := 0
var _failures: Array[String] = []
var _privacy_leaks: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_human_gate()
	_finish()


func _run_human_gate() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "real main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "real main uses the isolated QA save path before entering the tree")
	var rng_variant: Variant = main.get("rng")
	if rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).seed = FIXED_SEED
	root.add_child(main)
	await _wait_frames(8)

	main.call("_open_main_menu")
	await _wait_frames(2)
	var lobby: Dictionary = main.call("_main_menu_root_lobby_snapshot")
	_expect(_contains_action_id(lobby, "new_run"), "main menu exposes the real new-run command")
	main.call("_on_menu_root_lobby_action_requested", "new_run")
	await _wait_frames(3)
	var setup_page := main.find_child("NewGameSetupPage", true, false)
	_expect(setup_page is CanvasItem and (setup_page as CanvasItem).is_visible_in_tree(), "new-run command opens the real setup page")

	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	main.call("_open_new_game_setup_menu")
	await _wait_frames(2)
	var setup_snapshot: Dictionary = main.call("_new_game_setup_page_snapshot")
	var seats: Array = setup_snapshot.get("seats", []) if setup_snapshot.get("seats", []) is Array else []
	_expect(seats.size() == 3, "setup snapshot contains one human seat and two AI seats")
	if seats.size() == 3:
		var human: Dictionary = seats[0] if seats[0] is Dictionary else {}
		var ai_one: Dictionary = seats[1] if seats[1] is Dictionary else {}
		var ai_two: Dictionary = seats[2] if seats[2] is Dictionary else {}
		_expect(str(human.get("seat_type", "")) == "human" and str(ai_one.get("seat_type", "")) == "ai" and str(ai_two.get("seat_type", "")) == "ai", "setup preserves the 1-human plus 2-AI seat assignment")
		_expect(_seat_has_public_role(human) and _seat_has_public_role(ai_one) and _seat_has_public_role(ai_two), "all seats expose their public role card")
		_expect(_seat_has_human_starter(human), "the local human can inspect the selected starter monster")
		_expect(_ai_starter_is_anonymous(main, ai_one, 1) and _ai_starter_is_anonymous(main, ai_two, 2), "AI starter choices remain anonymous during setup")

	main.call("_on_new_game_setup_action_requested", "setup_start")
	await _wait_frames(10)
	main.set_process(false)
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null, "real GameRuntimeCoordinator is composed")
	if coordinator == null:
		main.queue_free()
		await process_frame
		return
	var players := _array_property(main, "players")
	_expect(_three_seats_are_live(players), "setup_start creates one live human and two live AI players")
	var actor_id := _actor_id(players, 0)
	var district := int(main.call("_first_run_recommended_start_district", 0))
	_expect(district >= 0, "first table provides a recommended human start district")
	if district >= 0:
		main.call("_select_district", district)

	var monster: Object = coordinator.call("monster_runtime_controller") if coordinator.has_method("monster_runtime_controller") else null
	var monster_before: Dictionary = monster.call("unit_card_snapshot_v06", "monster") if monster != null and monster.has_method("unit_card_snapshot_v06") else {}
	var monster_save_before: Dictionary = monster.call("to_save_data") if monster != null and monster.has_method("to_save_data") else {}
	var journal_before: Dictionary = monster_save_before.get("monster_card_atomic_terminal_journal", {}) if monster_save_before.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}
	var summon_submitted := bool(main.call("_activate_first_run_coach_action", "coach_first_summon"))
	var summon_drained := await _drain_card_resolution(main, 240)
	var monster_after: Dictionary = monster.call("unit_card_snapshot_v06", "monster") if monster != null and monster.has_method("unit_card_snapshot_v06") else {}
	var monster_save_after: Dictionary = monster.call("to_save_data") if monster != null and monster.has_method("to_save_data") else {}
	var journal_after: Dictionary = monster_save_after.get("monster_card_atomic_terminal_journal", {}) if monster_save_after.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}
	var new_monster_transactions := _new_dictionary_keys(journal_before, journal_after)
	var summon_finalized := new_monster_transactions.size() == 1 and _monster_terminal_finalized(journal_after, str(new_monster_transactions[0]))
	_expect(summon_submitted and summon_drained, "human first-summon submits and drains through the real card-resolution route")
	_expect(int(monster_after.get("monster_count", -1)) == int(monster_before.get("monster_count", -1)) + 1 and summon_finalized, "human first-summon creates one finalized authoritative monster transaction")

	if district >= 0:
		main.call("_open_district_supply_from_map", district)
		await _wait_frames(3)
	var supply_overlay: Variant = main.get("district_supply_overlay")
	_expect(supply_overlay is CanvasItem and (supply_overlay as CanvasItem).is_visible_in_tree(), "selected region opens the real district card drawer")
	var purchase_window: Dictionary = coordinator.call("district_purchase_private_ui_snapshot", 0) if coordinator.has_method("district_purchase_private_ui_snapshot") else {}
	_expect(bool(purchase_window.get("active", false)) and int(purchase_window.get("district_index", -1)) == district, "district drawer opens the real purchase window for the local human")

	var canonical_card: Dictionary = coordinator.call("v06_first_table_facility_card") if coordinator.has_method("v06_first_table_facility_card") else {}
	var canonical_machine: Dictionary = canonical_card.get("machine", {}) if canonical_card.get("machine", {}) is Dictionary else {}
	var canonical_card_id := str(canonical_machine.get("card_id", ""))
	var reserved: Dictionary = coordinator.call("reserve_district_purchase_discard", {"player_index": 0, "district_index": district, "card_id": canonical_card_id}) if coordinator.has_method("reserve_district_purchase_discard") else {}
	var pending_window: Dictionary = coordinator.call("district_purchase_private_ui_snapshot", 0) if coordinator.has_method("district_purchase_private_ui_snapshot") else {}
	_expect(not reserved.is_empty() and str(pending_window.get("state", "")) == "pending_discard", "purchase window exposes the private pending-discard state")
	var discard_resolved: Dictionary = coordinator.call("resolve_district_purchase_discard", {"player_index": 0, "reason": "a9_capability_checked"}) if coordinator.has_method("resolve_district_purchase_discard") else {}
	_expect(str(discard_resolved.get("state", "")) == "active", "discard capability returns to the active purchase window without mutating a card")

	var market_surface: Dictionary = coordinator.call("v06_first_table_facility_market_snapshot", actor_id) if coordinator.has_method("v06_first_table_facility_market_snapshot") else {}
	var listing: Dictionary = market_surface.get("listing", {}) if market_surface.get("listing", {}) is Dictionary else {}
	var source_item_id := str(listing.get("item_id", ""))
	var purchase: Dictionary = coordinator.call("purchase_v06_first_table_facility_card", actor_id, source_item_id, "vs06-a9:facility-purchase:%s" % actor_id) if coordinator.has_method("purchase_v06_first_table_facility_card") else {}
	var player_after_purchase: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id) if coordinator.has_method("v06_card_player_snapshot") else {}
	var purchased_card_id := str(purchase.get("card_id", canonical_card_id))
	var slot_index := _find_v06_card_slot(player_after_purchase, purchased_card_id)
	var region_id := _selected_region_id(main)
	var play_request := {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": "vs06-a9:facility-play:%s" % actor_id,
		"region_id": region_id,
		"game_time": float(main.get("game_time")),
	}
	var play: Dictionary = coordinator.call("play_v06_runtime_card", play_request) if bool(purchase.get("committed", false)) and slot_index >= 0 and not region_id.is_empty() and coordinator.has_method("play_v06_runtime_card") else {}
	var play_finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(purchase.get("committed", false)) and slot_index >= 0, "human purchases one canonical first-table facility through the Coordinator facade")
	_expect(bool(play.get("committed", false)) and bool(play_finalization.get("finalized", false)), "human plays that card through the existing Coordinator facade and reaches finalization")

	main.call("_close_district_supply_overlay")
	main.call("_refresh_ui")
	await _wait_frames(3)
	var planet_board := main.find_child("PlanetBoard", true, false) as Control
	var planet_map := main.find_child("PlanetMapView", true, false) as Control
	var player_board := main.find_child("PlayerBoard", true, false) as Control
	var hand_rack := main.find_child("HandRack", true, false) as Control
	var public_track := main.find_child("PublicTrack", true, false) as Control
	_expect(_visible_nonzero(planet_board) and _visible_nonzero(planet_map), "the human table keeps the sceneized planet map visible")
	_expect(_visible_nonzero(player_board) and _visible_nonzero(hand_rack), "the human table keeps the local hand surface visible")
	var track_debug: Dictionary = public_track.call("get_debug_snapshot") if public_track != null and public_track.has_method("get_debug_snapshot") else {}
	_expect(_visible_nonzero(public_track) and bool(track_debug.get("exposes_sceneized_resolution_track", false)) and not bool(track_debug.get("has_private_text", true)), "the anonymous public track is visible and reports no private text")

	var players_backup := players.duplicate(true)
	if players.size() >= 2 and players[1] is Dictionary:
		var ai_player := (players[1] as Dictionary).duplicate(true)
		ai_player["cash"] = 987654321
		ai_player["cash_cents"] = 98765432100
		ai_player["slots"] = [{"name": "VS06_PRIVATE_HAND_SENTINEL_A"}, {"name": "VS06_PRIVATE_HAND_SENTINEL_B"}]
		ai_player["ai_memory"] = {"route_plan": "VS06_AI_PLAN_SENTINEL"}
		ai_player["hidden_owner"] = "VS06_TRUE_OWNER_SENTINEL"
		players[1] = ai_player
		main.set("players", players)
	var ai_supply: Dictionary = main.call("_district_supply_snapshot_source", district, 1, 0) if district >= 0 else {}
	var victory_public: Dictionary = coordinator.call("victory_control_public_snapshot", -1) if coordinator.has_method("victory_control_public_snapshot") else {}
	_scan_public_value(setup_snapshot, "setup.public")
	_scan_public_value(ai_supply, "district_supply.public")
	_scan_public_value(victory_public, "victory.public")

	var victory_controller: Node = coordinator.call("victory_control_runtime_controller") if coordinator.has_method("victory_control_runtime_controller") else null
	var settlement_world: Dictionary = coordinator.call("victory_control_world_snapshot") if coordinator.has_method("victory_control_world_snapshot") else {}
	settlement_world["irreversible_planet_destruction_triggered"] = true
	settlement_world["scenario_allows_cash_fallback"] = true
	var settlement_receipt: Dictionary = victory_controller.call("resolve_special_outcome", "planet_destroyed", settlement_world) if victory_controller != null else {}
	if not settlement_receipt.is_empty() and coordinator.has_method("_apply_victory_outcome_receipt"):
		coordinator.call("_apply_victory_outcome_receipt", settlement_receipt)
	await _wait_frames(3)
	var settlement_diagnostic_title := "A9终局面板能力检查"
	var settlement_composition := main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition")
	var settlement_snapshot: Dictionary = settlement_composition.call("last_public_snapshot") if settlement_composition != null and settlement_composition.has_method("last_public_snapshot") else {}
	var settlement_source: Dictionary = settlement_composition.call("compose_public_source", _settlement_public_context(main, coordinator)) if settlement_composition != null and settlement_composition.has_method("compose_public_source") else {}
	var coordinator_snapshot: Dictionary = coordinator.call("compose_final_settlement_snapshot", settlement_source) if coordinator.has_method("compose_final_settlement_snapshot") else {}
	var settlement_board: Control = null
	if settlement_composition != null and settlement_composition.has_method("board_node"):
		settlement_board = settlement_composition.call("board_node") as Control
	_expect(not settlement_receipt.is_empty() and settlement_snapshot == coordinator_snapshot and settlement_board != null and settlement_board.has_method("set_board") and settlement_board.has_signal("action_requested") and _visible_nonzero(settlement_board), "%s: the real Final Settlement composition presents one visible non-zero board from the Coordinator public snapshot service" % settlement_diagnostic_title)
	_scan_public_value(settlement_snapshot, "settlement.public")
	_scan_visible_controls(main, "main.visible")
	_expect(_privacy_leaks.is_empty(), "public snapshots and visible controls recursively omit opponent cash, hand, owner truth, and AI plans: %s" % [_privacy_leaks])

	main.set("players", players_backup)
	main.queue_free()
	await process_frame


func _seat_has_public_role(seat: Dictionary) -> bool:
	var faces: Array = seat.get("card_faces", []) if seat.get("card_faces", []) is Array else []
	return not str(seat.get("role_label", "")).is_empty() and not faces.is_empty() and faces[0] is Dictionary and str((faces[0] as Dictionary).get("card_kind", "")) == "player_role"


func _settlement_public_context(main: Node, coordinator: Node) -> Dictionary:
	var players := _array_property(main, "players")
	var participant_names: Dictionary = {}
	for player_index in range(players.size()):
		participant_names[str(player_index)] = str(main.call("_player_name", player_index))
	return {
		"victory_public_snapshot": coordinator.call("victory_control_public_snapshot", -1),
		"participant_names": participant_names,
	}


func _seat_has_human_starter(seat: Dictionary) -> bool:
	var faces: Array = seat.get("card_faces", []) if seat.get("card_faces", []) is Array else []
	return str(seat.get("seat_type", "")) == "human" and not str(seat.get("monster_label", "")).is_empty() and faces.size() >= 2


func _ai_starter_is_anonymous(main: Node, seat: Dictionary, player_index: int) -> bool:
	var configured_index := int(main.call("_configured_starter_monster_index", player_index))
	var catalog_entry: Dictionary = main.call("_catalog_entry", configured_index)
	var exact_name := str(catalog_entry.get("name", "")).strip_edges()
	var encoded := JSON.stringify(seat)
	var faces: Array = seat.get("card_faces", []) if seat.get("card_faces", []) is Array else []
	return str(seat.get("seat_type", "")) == "ai" \
		and not seat.has("monster_label") \
		and not seat.has("starter_note") \
		and faces.size() == 1 \
		and (exact_name.is_empty() or not encoded.contains(exact_name))


func _three_seats_are_live(players: Array) -> bool:
	return players.size() == 3 \
		and players[0] is Dictionary and not bool((players[0] as Dictionary).get("is_ai", true)) \
		and players[1] is Dictionary and bool((players[1] as Dictionary).get("is_ai", false)) \
		and players[2] is Dictionary and bool((players[2] as Dictionary).get("is_ai", false))


func _monster_terminal_finalized(journal: Dictionary, transaction_id: String) -> bool:
	var terminal: Dictionary = journal.get(transaction_id, {}) if journal.get(transaction_id, {}) is Dictionary else {}
	var receipt: Dictionary = terminal.get("receipt", {}) if terminal.get("receipt", {}) is Dictionary else {}
	return str(terminal.get("stage", "")) == "finalized" and bool(receipt.get("finalized", false))


func _find_v06_card_slot(player: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _selected_region_id(main: Node) -> String:
	var districts := _array_property(main, "districts")
	var index := int(main.get("selected_district"))
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return ""
	return str((districts[index] as Dictionary).get("region_id", "")).strip_edges()


func _actor_id(players: Array, player_index: int) -> String:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return ""
	var configured := str((players[player_index] as Dictionary).get("actor_id", "")).strip_edges()
	return configured if not configured.is_empty() else "player.%d" % player_index


func _new_dictionary_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant in after.keys():
		var key := str(key_variant)
		if not before.has(key):
			result.append(key)
	result.sort()
	return result


func _array_property(node: Object, property_name: String) -> Array:
	var value: Variant = node.get(property_name)
	return value as Array if value is Array else []


func _visible_nonzero(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0


func _card_queue_idle(main: Node) -> bool:
	var active: Variant = main.get("active_card_resolution")
	var queue: Variant = main.get("card_resolution_queue")
	var next_queue: Variant = main.get("next_card_resolution_queue")
	return (not (active is Dictionary) or (active as Dictionary).is_empty()) \
		and (not (queue is Array) or (queue as Array).is_empty()) \
		and (not (next_queue is Array) or (next_queue as Array).is_empty()) \
		and not bool(main.get("card_resolution_batch_locked"))


func _drain_card_resolution(main: Node, max_frames: int) -> bool:
	for _frame in range(maxi(1, max_frames)):
		if _card_queue_idle(main):
			return true
		main.call("_update_card_resolution_queue", 0.5)
		await process_frame
	return _card_queue_idle(main)


func _contains_action_id(value: Variant, action_id: String) -> bool:
	if value is Dictionary:
		if str((value as Dictionary).get("id", "")) == action_id:
			return true
		for nested in (value as Dictionary).values():
			if _contains_action_id(nested, action_id):
				return true
	elif value is Array:
		for nested in value:
			if _contains_action_id(nested, action_id):
				return true
	return false


func _scan_public_value(value: Variant, path: String) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if FORBIDDEN_PUBLIC_KEYS.has(key.to_lower()):
				_privacy_leaks.append("%s.%s:forbidden_key" % [path, key])
			_scan_public_value((value as Dictionary).get(key_variant), "%s.%s" % [path, key])
		return
	if value is Array:
		for index in range((value as Array).size()):
			_scan_public_value((value as Array)[index], "%s[%d]" % [path, index])
		return
	var text := str(value)
	for sentinel in PRIVATE_VALUE_SENTINELS:
		if text.contains(sentinel):
			_privacy_leaks.append("%s:private_value:%s" % [path, sentinel])


func _scan_visible_controls(node: Node, path: String) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var fragments: Array[String] = [(node as Control).tooltip_text]
		if node is Label:
			fragments.append((node as Label).text)
		elif node is RichTextLabel:
			fragments.append((node as RichTextLabel).text)
		elif node is Button:
			fragments.append((node as Button).text)
		elif node is LineEdit:
			fragments.append((node as LineEdit).text)
		for fragment in fragments:
			for sentinel in PRIVATE_VALUE_SENTINELS:
				if fragment.contains(sentinel):
					_privacy_leaks.append("%s/%s:visible_private_value:%s" % [path, node.name, sentinel])
	for child in node.get_children():
		_scan_visible_controls(child, "%s/%s" % [path, node.name])


func _wait_frames(count: int) -> void:
	for _frame in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("HUMAN_FIRST_TABLE_PLAYABILITY_V06_TEST|status=%s|checks=%d|failures=%d|privacy_leaks=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), _privacy_leaks.size()])
	quit(_failures.size())
