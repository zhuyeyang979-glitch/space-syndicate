extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/human_normal_table_playability_v06.save"
const REMOVED_TOKENS := [
	"campaign",
	"tutorial",
	"first_run",
	"coach",
	"reward",
	"checkpoint",
]
const PRIVATE_SENTINELS := [
	"987654321",
	"NORMAL_TABLE_PRIVATE_HAND_SENTINEL",
	"NORMAL_TABLE_TRUE_OWNER_SENTINEL",
	"NORMAL_TABLE_AI_PLAN_SENTINEL",
]

var _checks := 0
var _failures: Array[String] = []
var _privacy_leaks: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "normal-table gate uses an isolated save path")
	root.add_child(main)
	await _wait_frames(6)

	var lobby: Dictionary = main.call("_main_menu_root_lobby_snapshot")
	_expect(_has_action(lobby, "new_run"), "main menu exposes new game")
	_expect(_has_action(lobby, "continue"), "main menu exposes continue")
	_expect(_has_action(lobby, "compendium"), "main menu exposes compendium")
	_expect(_has_action(lobby, "rules"), "main menu exposes rules")
	_expect(not _contains_removed_token(var_to_str(lobby)), "main menu has no removed onboarding action or copy")

	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	main.call("_open_new_game_setup_menu")
	await _wait_frames(2)
	var setup_page := main.find_child("NewGameSetupPage", true, false)
	_expect(setup_page is CanvasItem and (setup_page as CanvasItem).is_visible_in_tree(), "new-game setup page opens")
	_expect(main.find_child("FirstRunRecommendedSetupButton", true, false) == null, "setup has no legacy recommended-first-run button")

	main.call("_on_new_game_setup_action_requested", "setup_start")
	await _wait_frames(10)
	main.set_process(false)
	var players: Array = ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players if ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players is Array else []
	_expect(players.size() == 3, "normal game creates one human and two AI seats")
	_expect(main.find_child("RuntimeGameScreen", true, false) != null, "normal game screen remains composed")
	_expect(main.find_child("PlanetBoard", true, false) != null, "PlanetBoard remains composed")
	_expect(main.find_child("PlayerBoard", true, false) != null, "PlayerBoard remains composed")
	_expect(main.find_child("FirstRunCoach", true, false) == null and main.find_child("ScenarioCoach", true, false) == null, "normal table has no legacy coach nodes")

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null, "GameRuntimeCoordinator remains composed")
	if coordinator != null:
		var save_data: Dictionary = coordinator.call("session_to_save_data")
		_expect(not _contains_removed_token(var_to_str(save_data)), "new session save data has no onboarding/campaign fields")
		var district := _first_playable_district(main)
		_expect(district >= 0, "normal table has a playable region")
		if district >= 0:
			main.call("_select_district", district)
			main.call("_open_district_supply_from_map", district)
			await _wait_frames(3)

		var actor_id := _actor_id(players, 0)
		coordinator.call("refresh_v06_production_player_bindings", main)
		var player_before: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
		var hand_before := _inventory_card_count(player_before)
		var market: Dictionary = coordinator.call("v06_facility_market_snapshot", actor_id)
		var listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
		var listing_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
		var listing_machine: Dictionary = listing_card.get("machine", {}) if listing_card.get("machine", {}) is Dictionary else {}
		var listing_card_id := str(listing_machine.get("card_id", ""))
		coordinator.call("restore_world_effective_seconds", 0.0)
		coordinator.call("refresh_v06_facility_quote", actor_id, listing_card_id)
		market = coordinator.call("v06_facility_market_snapshot", actor_id)
		listing = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
		var item_id := str(listing.get("item_id", ""))
		var purchase: Dictionary = coordinator.call("purchase_v06_facility_card", actor_id, item_id, "normal-table:facility-purchase")
		var player_after_purchase: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
		var purchased_card_id := str(purchase.get("card_id", ""))
		var slot_index := _find_v06_card_slot(player_after_purchase, purchased_card_id)
		_expect(bool(purchase.get("committed", false)) and slot_index >= 0, "human buys a normal v0.6 facility card")
		_expect(_inventory_card_count(player_after_purchase) == hand_before + 1, "facility purchase adds exactly one visible hand card")

		var region_id := _selected_region_id(main)
		var play_request := {
			"actor_id": actor_id,
			"slot_index": slot_index,
			"transaction_id": "normal-table:facility-play",
			"region_id": region_id,
			"game_time": float(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time),
		}
		var play: Dictionary = coordinator.call("play_v06_runtime_card", play_request) if slot_index >= 0 and not region_id.is_empty() else {}
		var finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
		_expect(bool(play.get("committed", false)) and bool(finalization.get("finalized", false)), "human plays the purchased facility through the normal CardFlow route")
		var player_after_play: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
		_expect(_inventory_card_count(player_after_play) == hand_before, "facility finalization removes the played card from hand")

		main.call("_close_district_supply_overlay")
		main.call("_refresh_ui")
		await _wait_frames(3)
		var planet_map := main.find_child("PlanetMapView", true, false) as Control
		var hand_rack := main.find_child("HandRack", true, false) as Control
		var public_track := main.find_child("PublicTrack", true, false) as Control
		_expect(_visible_nonzero(planet_map) and _visible_nonzero(hand_rack), "normal table keeps the map and local hand visible")
		var track_debug: Dictionary = public_track.call("get_debug_snapshot") if public_track != null and public_track.has_method("get_debug_snapshot") else {}
		_expect(_visible_nonzero(public_track) and not bool(track_debug.get("has_private_text", true)), "normal public track stays visible and privacy-safe")

		var players_backup := players.duplicate(true)
		if players.size() >= 2 and players[1] is Dictionary:
			var rival := (players[1] as Dictionary).duplicate(true)
			rival["cash"] = 987654321
			rival["cash_cents"] = 98765432100
			rival["slots"] = [{"name": "NORMAL_TABLE_PRIVATE_HAND_SENTINEL"}]
			rival["ai_memory"] = {"route_plan": "NORMAL_TABLE_AI_PLAN_SENTINEL"}
			rival["hidden_owner"] = "NORMAL_TABLE_TRUE_OWNER_SENTINEL"
			players[1] = rival
			((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
		var rival_supply: Dictionary = main.call("_district_supply_snapshot_source", district, 1, 0)
		var victory_public: Dictionary = coordinator.call("victory_control_public_snapshot", -1)
		_scan_public_value(rival_supply, "district_supply.public")
		_scan_public_value(victory_public, "victory.public")

		var victory_controller: Node = coordinator.call("victory_control_runtime_controller")
		var settlement_world: Dictionary = coordinator.call("victory_control_world_snapshot")
		settlement_world["irreversible_planet_destruction_triggered"] = true
		settlement_world["scenario_allows_cash_fallback"] = true
		var settlement_receipt: Dictionary = victory_controller.call("resolve_special_outcome", "planet_destroyed", settlement_world) if victory_controller != null else {}
		if not settlement_receipt.is_empty() and coordinator.has_method("_apply_victory_outcome_receipt"):
			coordinator.call("_apply_victory_outcome_receipt", settlement_receipt)
		await _wait_frames(3)
		var settlement_composition := main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition")
		var settlement_snapshot: Dictionary = settlement_composition.call("last_public_snapshot") if settlement_composition != null else {}
		var settlement_board: Control = settlement_composition.call("board_node") as Control if settlement_composition != null and settlement_composition.has_method("board_node") else null
		_expect(not settlement_receipt.is_empty() and not settlement_snapshot.is_empty(), "normal victory route produces a public final-settlement snapshot")
		_expect(_visible_nonzero(settlement_board) and settlement_board.has_signal("action_requested"), "FinalSettlementRuntimeComposition presents the normal result board")
		_scan_public_value(settlement_snapshot, "settlement.public")
		_scan_visible_controls(main, "main.visible")
		_expect(_privacy_leaks.is_empty(), "public surfaces omit rival cash, hand, owner truth, and AI plan sentinels")
		((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players_backup

		var save_service := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
		var handshake := save_service.get_node_or_null("RulesetSaveHandshakeService") if save_service != null else null
		var envelope := _transport_envelope(handshake)
		var authorization: Dictionary = save_service.call("write_authorization", QA_SAVE_PATH, envelope, {"allow_replace": true}) if save_service != null and not envelope.is_empty() else {}
		var save_result: Dictionary = save_service.call("write_validated_envelope", QA_SAVE_PATH, envelope, authorization) if save_service != null else {}
		_expect(bool(save_result.get("ok", false)), "normal table writes an authorized v0.6 save envelope")
		var load_result: Dictionary = save_service.call("read_and_validate", QA_SAVE_PATH) if save_service != null else {}
		_expect(bool(load_result.get("ok", false)) and str(load_result.get("fingerprint", "")) == str(save_result.get("fingerprint", "")), "normal table reads back the same validated save envelope")

	main.queue_free()
	await process_frame
	_finish()


func _has_action(snapshot: Dictionary, action_id: String) -> bool:
	for key in ["actions", "utilities"]:
		var entries: Array = snapshot.get(key, []) if snapshot.get(key, []) is Array else []
		for entry_variant in entries:
			if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == action_id:
				return true
	return false


func _contains_removed_token(text: String) -> bool:
	var lower := text.to_lower()
	for token in REMOVED_TOKENS:
		if lower.contains(token):
			return true
	return false


func _first_playable_district(main: Node) -> int:
	var districts: Array = ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts if ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts is Array else []
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if not bool(district.get("is_ocean", false)) and not bool(district.get("destroyed", false)) and not str(district.get("region_id", "")).is_empty():
			return index
	return -1


func _selected_region_id(main: Node) -> String:
	var districts: Array = ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts if ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts is Array else []
	var index := int(((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district)
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return ""
	return str((districts[index] as Dictionary).get("region_id", ""))


func _actor_id(players: Array, player_index: int) -> String:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return ""
	var actor_id := str((players[player_index] as Dictionary).get("actor_id", ""))
	return actor_id if not actor_id.is_empty() else "player.%d" % player_index


func _inventory_card_count(player_snapshot: Dictionary) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		var slot: Dictionary = slot_variant if slot_variant is Dictionary else {}
		if not slot.is_empty() and not (slot.get("machine", {}) as Dictionary).is_empty():
			count += 1
	return count


func _find_v06_card_slot(player_snapshot: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for index in range(slots.size()):
		var slot: Dictionary = slots[index] if slots[index] is Dictionary else {}
		var machine: Dictionary = slot.get("machine", {}) if slot.get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return index
	return -1


func _visible_nonzero(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0


func _transport_envelope(handshake: Node) -> Dictionary:
	if handshake == null:
		return {}
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var session_section: Dictionary = {}
	var domain_sections: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var contract: Dictionary = manifest.get(section_id, {}) if manifest.get(section_id, {}) is Dictionary else {}
		var section_payload := {
			"schema_version": int(contract.get("state_version", 0)),
			"revision": 0,
			"normal_table_transport": true,
		}
		if section_id == "session":
			session_section = section_payload
		else:
			domain_sections[section_id] = section_payload
	return handshake.call("compose_v06_envelope", session_section, domain_sections, {
		"envelope_id": "normal-table-envelope",
		"write_id": "normal-table-write",
	}) as Dictionary


func _scan_public_value(value: Variant, path: String) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if key in ["hidden_owner", "private_hand", "ai_memory", "ai_plan", "utility_scores", "cash_ledger_cents"]:
				_privacy_leaks.append("%s.%s:forbidden_key" % [path, key])
			_scan_public_value((value as Dictionary).get(key_variant), "%s.%s" % [path, key])
		return
	if value is Array:
		for index in range((value as Array).size()):
			_scan_public_value((value as Array)[index], "%s[%d]" % [path, index])
		return
	var text := str(value)
	for sentinel in PRIVATE_SENTINELS:
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
		for fragment in fragments:
			for sentinel in PRIVATE_SENTINELS:
				if fragment.contains(sentinel):
					_privacy_leaks.append("%s/%s:visible_private_value:%s" % [path, node.name, sentinel])
	for child in node.get_children():
		_scan_visible_controls(child, "%s/%s" % [path, node.name])


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Human normal-table playability v0.6 passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Human normal-table playability v0.6 failed:\n- " + "\n- ".join(_failures))
	quit(1)
