extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const LAYOUT_DEMO_SCENE_PATH := "res://scenes/LayoutDemo.tscn"
const SNAPSHOT_DIR := "user://space_syndicate_ui_snapshots"
const CAPTURE_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _saved_paths: Array[String] = []
var _capture_failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_snapshot_dir()
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if not (packed is PackedScene):
		push_error("UI snapshot capture failed: main scene did not load.")
		quit(1)
		return
	var layout_demo_packed := load(LAYOUT_DEMO_SCENE_PATH) as PackedScene
	if not (layout_demo_packed is PackedScene):
		push_error("UI snapshot capture failed: layout demo scene did not load.")
		quit(1)
		return
	for capture_size in CAPTURE_SIZES:
		await _capture_size_suite(packed, layout_demo_packed, capture_size)
	if _capture_failures.is_empty():
		print("UI snapshot capture complete:")
		for path in _saved_paths:
			print(path)
		quit(0)
	else:
		printerr("UI snapshot capture failed:")
		for failure in _capture_failures:
			printerr("- %s" % failure)
		quit(1)


func _capture_size_suite(packed: PackedScene, layout_demo_packed: PackedScene, capture_size: Vector2i) -> void:
	_place_capture_window(capture_size)
	DisplayServer.window_set_size(capture_size)
	get_root().size = capture_size
	var suffix := "%dx%d" % [capture_size.x, capture_size.y]
	var main := packed.instantiate()
	get_root().add_child(main)
	await _pump_frames(10)

	main.call("_open_main_menu")
	await _pump_frames(8)
	await _save_viewport_snapshot("main_menu_%s.png" % suffix)

	main.call("_open_new_game_setup_menu")
	await _pump_frames(8)
	await _save_viewport_snapshot("new_game_setup_%s.png" % suffix)
	_scroll_named_container_to_bottom(main, "MenuContentScroll")
	await _pump_frames(2)
	_scroll_named_container_to_bottom(main, "NewGameSetupSeatScroll")
	await _pump_frames(4)
	await _save_viewport_snapshot("new_game_setup_seats_%s.png" % suffix)

	if main.has_method("_open_scenario_browser_menu"):
		main.call("_open_scenario_browser_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("scenario_browser_%s.png" % suffix)
	else:
		_capture_failures.append("scenario browser menu was not available for %s" % suffix)

	if capture_size == Vector2i(1600, 960):
		main.call("_open_tutorial_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("tutorial_quick_start_%s.png" % suffix)

		main.call("_open_rules_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("rules_quick_reference_%s.png" % suffix)

		main.call("_open_compendium_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("compendium_hub_%s.png" % suffix)

		main.call("_open_role_codex_menu", 0)
		await _pump_frames(8)
		await _save_viewport_snapshot("role_codex_detail_%s.png" % suffix)

		main.call("_open_card_codex_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("card_codex_grid_%s.png" % suffix)

		main.call("_open_card_codex_menu", 0)
		await _pump_frames(8)
		await _save_viewport_snapshot("card_codex_detail_%s.png" % suffix)

		main.call("_open_product_codex_menu", 0)
		await _pump_frames(8)
		await _save_viewport_snapshot("product_codex_detail_%s.png" % suffix)

		main.call("_open_bestiary_menu", 0)
		await _pump_frames(8)
		await _save_viewport_snapshot("bestiary_detail_%s.png" % suffix)

		for scenario_id in ["first_table", "market_hand", "public_track_intro", "bid_practice", "monster_pressure", "contract_goods", "intel_guess", "final_countdown"]:
			if main.has_method("_start_scenario_from_menu"):
				main.call("_start_scenario_from_menu", scenario_id)
				await _pump_frames(14)
				await _save_viewport_snapshot("scenario_%s_%s.png" % [scenario_id, suffix])
			else:
				_capture_failures.append("scenario start helper was not available for %s" % scenario_id)

	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	_clear_active_scenario_state(main)
	main.call("_new_game")
	if capture_size == Vector2i(1600, 960):
		main.call("_open_standings_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("standings_runtime_%s.png" % suffix)
		main.call("_open_economy_overview_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("economy_overview_runtime_%s.png" % suffix)
		main.call("_open_intel_dossier_menu")
		await _pump_frames(8)
		await _save_viewport_snapshot("intel_dossier_runtime_%s.png" % suffix)
		var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
		if coordinator != null and coordinator.has_method("resolve_victory_outcome"):
			coordinator.call("resolve_victory_outcome", "planet_destroyed", {})
		var settlement_rankings_variant: Variant = main.call("_victory_control_rankings")
		var settlement_rankings: Array = settlement_rankings_variant if settlement_rankings_variant is Array else []
		main.call("_open_final_settlement_menu", "截图验证", settlement_rankings)
		await _pump_frames(8)
		await _save_viewport_snapshot("final_settlement_runtime_%s.png" % suffix)
		main.call("_new_game")
		await _pump_frames(8)
	main.call("_close_menu")
	await _pump_frames(16)
	if _runtime_first_run_coach_visible(main):
		await _save_viewport_snapshot("first_run_coach_%s.png" % suffix)
	else:
		_capture_failures.append("runtime first-run coach was not visible for %s" % suffix)
	await _save_viewport_snapshot("play_table_%s.png" % suffix)
	if _open_runtime_supply_drawer_for_capture(main):
		await _pump_frames(8)
		if _runtime_supply_drawer_visible(main):
			await _save_viewport_snapshot("play_table_supply_drawer_%s.png" % suffix)
			_close_runtime_supply_drawer_for_capture(main)
			await _pump_frames(3)
		else:
			_capture_failures.append("runtime district supply drawer did not become visible for %s" % suffix)
	else:
		_capture_failures.append("runtime district supply drawer could not be opened for %s" % suffix)
	if capture_size == Vector2i(1600, 960):
		if _stage_runtime_planet_globe(main):
			await _pump_frames(8)
			await _save_viewport_snapshot("play_table_planet_globe_%s.png" % suffix)
		else:
			_capture_failures.append("runtime MapView globe overview was not available for %s" % suffix)
		if _stage_runtime_planet_local(main):
			await _pump_frames(8)
			await _save_viewport_snapshot("play_table_planet_zoom_local_%s.png" % suffix)
		else:
			_capture_failures.append("runtime MapView local projection was not available for %s" % suffix)
		if _stage_runtime_planet_globe(main):
			await _pump_frames(8)
			await _save_viewport_snapshot("play_table_planet_return_globe_%s.png" % suffix)
		else:
			_capture_failures.append("runtime MapView return-to-globe was not available for %s" % suffix)
	if capture_size == Vector2i(1600, 960):
		await _ensure_runtime_hand_for_capture(main)
		if _stage_runtime_hand_hover(main):
			await _pump_frames(6)
			await _save_viewport_snapshot("play_table_hand_hover_%s.png" % suffix)
			_clear_runtime_hand_hover(main)
		else:
			_capture_failures.append("runtime hand hover state was not available for %s" % suffix)
		if _stage_runtime_hand_selected(main):
			await _pump_frames(6)
			await _save_viewport_snapshot("play_table_hand_selected_%s.png" % suffix)
		else:
			_capture_failures.append("runtime hand selected state was not available for %s" % suffix)
	if _show_runtime_drag_drop_hint(main):
		await _pump_frames(6)
		await _save_viewport_snapshot("play_table_drag_drop_%s.png" % suffix)
		_hide_runtime_drag_drop_hint(main)
		await _pump_frames(2)
	else:
		_capture_failures.append("runtime drag-drop hint was not available for %s" % suffix)
	if _set_runtime_player_action_cooldown(main, 0, 2.5):
		if main.has_method("_sync_runtime_game_screen"):
			main.call("_sync_runtime_game_screen", true)
		await _pump_frames(4)
		if _show_runtime_drag_drop_hint(main):
			await _pump_frames(6)
			await _save_viewport_snapshot("play_table_drag_blocked_%s.png" % suffix)
			if capture_size == Vector2i(1600, 960):
				await _save_viewport_snapshot("play_table_drag_invalid_%s.png" % suffix)
			_hide_runtime_drag_drop_hint(main)
			await _pump_frames(2)
		else:
			_capture_failures.append("runtime blocked drag-drop hint was not available for %s" % suffix)
		_set_runtime_player_action_cooldown(main, 0, 0.0)
		if main.has_method("_sync_runtime_game_screen"):
			main.call("_sync_runtime_game_screen", true)
		await _pump_frames(4)
	else:
		_capture_failures.append("runtime cooldown state could not be staged for %s" % suffix)
	if _open_first_runtime_detail_drawer(main):
		await _pump_frames(8)
		if _runtime_side_drawer_visible(main):
			await _save_viewport_snapshot("play_table_drawer_%s.png" % suffix)
		else:
			_capture_failures.append("runtime detail drawer did not become visible for %s" % suffix)
	else:
		_capture_failures.append("runtime detail drawer link was not found for %s" % suffix)

	get_root().remove_child(main)
	main.queue_free()
	await _pump_frames(4)

	var layout_demo := layout_demo_packed.instantiate()
	get_root().add_child(layout_demo)
	await _pump_frames(8)
	await _save_viewport_snapshot("layout_demo_%s.png" % suffix)
	await _save_viewport_snapshot("hand_rack_demo_%s.png" % suffix)
	get_root().remove_child(layout_demo)
	layout_demo.queue_free()
	await _pump_frames(4)


func _clear_active_scenario_state(main: Node) -> void:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	if _node_has_property(main, "selected_scenario_id"):
		main.set("selected_scenario_id", "first_table")


func _node_has_property(node: Object, property_name: String) -> bool:
	for property_variant in node.get_property_list():
		var property: Dictionary = property_variant if property_variant is Dictionary else {}
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _pump_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _prepare_snapshot_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(SNAPSHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _place_capture_window(capture_size: Vector2i) -> void:
	var screen_count := DisplayServer.get_screen_count()
	var screen_index := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	var screen_position := DisplayServer.screen_get_position(screen_index)
	DisplayServer.window_set_position(screen_position + Vector2i(40, 40))
	DisplayServer.window_set_size(capture_size)


func _scroll_named_container_to_bottom(root_node: Node, node_name: String) -> void:
	var scroll := root_node.find_child(node_name, true, false) as ScrollContainer
	if scroll == null:
		return
	var vertical_bar := scroll.get_v_scroll_bar()
	if vertical_bar == null:
		return
	scroll.scroll_vertical = int(maxf(0.0, vertical_bar.max_value))


func _open_first_runtime_detail_drawer(root_node: Node) -> bool:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	var search_root: Node = runtime_screen if runtime_screen != null else root_node
	var deep_link_row := search_root.find_child("InspectorDeepLinkRow", true, false)
	if deep_link_row == null:
		return false
	for child in deep_link_row.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).emit_signal("pressed")
			return true
	return false


func _runtime_side_drawer_visible(root_node: Node) -> bool:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	var search_root: Node = runtime_screen if runtime_screen != null else root_node
	var drawer := search_root.find_child("SideDrawerPanel", true, false) as Control
	return drawer != null and drawer.visible and drawer.is_visible_in_tree()


func _open_runtime_supply_drawer_for_capture(root_node: Node) -> bool:
	if root_node == null or not root_node.has_method("_open_district_supply_from_map"):
		return false
	var district_index := _capture_district_with_cards(root_node)
	if district_index < 0:
		return false
	root_node.call("_open_district_supply_from_map", district_index)
	return true


func _close_runtime_supply_drawer_for_capture(root_node: Node) -> void:
	if root_node != null and root_node.has_method("_close_district_supply_overlay"):
		root_node.call("_close_district_supply_overlay")


func _runtime_supply_drawer_visible(root_node: Node) -> bool:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	var search_root: Node = runtime_screen if runtime_screen != null else root_node
	var drawer := search_root.find_child("DistrictSupplySideDrawerOverlay", true, false) as Control
	var market_grid := search_root.find_child("DistrictSupplyMarketGrid", true, false) as Control
	var preview_panel := search_root.find_child("DistrictSupplyPreviewPanel", true, false) as Control
	return drawer != null and drawer.visible and drawer.is_visible_in_tree() \
		and market_grid != null and market_grid.is_visible_in_tree() \
		and preview_panel != null and preview_panel.is_visible_in_tree()


func _capture_district_with_cards(root_node: Node) -> int:
	var districts_variant: Variant = root_node.get("districts")
	if not (districts_variant is Array):
		return int(root_node.get("selected_district")) if _node_has_property(root_node, "selected_district") else -1
	var districts: Array = districts_variant as Array
	var selected := int(root_node.get("selected_district")) if _node_has_property(root_node, "selected_district") else -1
	if _district_has_capture_cards(districts, selected):
		return selected
	for i in range(districts.size()):
		if _district_has_capture_cards(districts, i):
			return i
	return selected if selected >= 0 and selected < districts.size() else -1


func _district_has_capture_cards(districts: Array, index: int) -> bool:
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return false
	var district: Dictionary = districts[index] as Dictionary
	if bool(district.get("destroyed", false)):
		return false
	var choices_variant: Variant = district.get("card_choices", [])
	return choices_variant is Array and not (choices_variant as Array).is_empty()


func _runtime_first_run_coach_visible(root_node: Node) -> bool:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	if runtime_screen == null:
		return false
	var coach := runtime_screen.find_child("FirstRunCoach", true, false) as Control
	var button := runtime_screen.find_child("CoachPrimaryButton", true, false) as Button
	return coach != null and coach.visible and coach.is_visible_in_tree() and button != null


func _stage_runtime_hand_hover(root_node: Node) -> bool:
	var hand_rack := _runtime_hand_rack(root_node)
	var card := _runtime_hand_card_at(hand_rack, 0)
	if card == null:
		card = _runtime_visible_hand_card(root_node, 0)
	if card == null:
		return false
	if hand_rack == null or not hand_rack.has_method("set_hovered_card"):
		hand_rack = card.get_parent()
	if hand_rack == null or not hand_rack.has_method("set_hovered_card"):
		return false
	hand_rack.call("set_hovered_card", card)
	if card.has_method("get_card_data"):
		var data_variant: Variant = card.call("get_card_data")
		if hand_rack.has_signal("card_hovered"):
			hand_rack.emit_signal("card_hovered", data_variant if data_variant is Dictionary else {})
	return true


func _clear_runtime_hand_hover(root_node: Node) -> void:
	var hand_rack := _runtime_hand_rack(root_node)
	if hand_rack != null and hand_rack.has_method("set_hovered_card"):
		hand_rack.call("set_hovered_card", null)
		if hand_rack.has_signal("card_unhovered"):
			hand_rack.emit_signal("card_unhovered")


func _stage_runtime_hand_selected(root_node: Node) -> bool:
	var hand_rack := _runtime_hand_rack(root_node)
	var card := _runtime_hand_card_at(hand_rack, 0)
	if card == null:
		card = _runtime_visible_hand_card(root_node, 0)
	if card == null:
		return false
	if hand_rack == null or not hand_rack.has_method("set_selected_card"):
		hand_rack = card.get_parent()
	if hand_rack == null or not hand_rack.has_method("set_selected_card"):
		return false
	hand_rack.call("set_selected_card", card)
	if card.has_method("get_card_data") and hand_rack.has_signal("card_selected"):
		var data_variant: Variant = card.call("get_card_data")
		hand_rack.emit_signal("card_selected", data_variant if data_variant is Dictionary else {})
	return true


func _runtime_hand_rack(root_node: Node) -> Node:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	if runtime_screen == null:
		return null
	var candidates := _runtime_hand_rack_candidates(runtime_screen)
	for candidate in candidates:
		if candidate is Control and (candidate as Control).is_visible_in_tree() and _runtime_hand_card_at(candidate, 0) != null:
			return candidate
	for candidate in candidates:
		if candidate is Control and (candidate as Control).is_visible_in_tree():
			return candidate
	return candidates[0] if not candidates.is_empty() else null


func _runtime_hand_rack_candidates(root_node: Node) -> Array:
	var result: Array = []
	_collect_runtime_hand_racks(root_node, result)
	return result


func _collect_runtime_hand_racks(node: Node, result: Array) -> void:
	if node == null:
		return
	if node.name == "HandRack" and node.has_method("set_cards"):
		result.append(node)
	for child in node.get_children():
		_collect_runtime_hand_racks(child, result)


func _runtime_hand_card_at(hand_rack: Node, index: int) -> Control:
	if hand_rack == null:
		return null
	var card_index := 0
	for child in hand_rack.get_children():
		if child is Control and child.has_method("get_card_data"):
			if card_index == index:
				return child as Control
			card_index += 1
	return null


func _runtime_visible_hand_card(root_node: Node, index: int) -> Control:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	if runtime_screen == null:
		return null
	var cards: Array = []
	_collect_runtime_hand_cards(runtime_screen, cards)
	return cards[index] if index >= 0 and index < cards.size() else null


func _collect_runtime_hand_cards(node: Node, result: Array) -> void:
	if node == null:
		return
	if node is Control and node.name.begins_with("MiniHandCardFace") and node.has_method("get_card_data") and (node as Control).is_visible_in_tree():
		result.append(node)
	for child in node.get_children():
		_collect_runtime_hand_cards(child, result)


func _ensure_runtime_hand_for_capture(root_node: Node) -> void:
	if _runtime_visible_hand_card(root_node, 0) != null:
		return
	var players_variant: Variant = root_node.get("players")
	if not (players_variant is Array):
		return
	var players: Array = (players_variant as Array).duplicate(true)
	if players.is_empty():
		return
	var selected_index := clampi(int(root_node.get("selected_player")), 0, players.size() - 1)
	if not (players[selected_index] is Dictionary):
		return
	var player: Dictionary = (players[selected_index] as Dictionary).duplicate(true)
	var slots_variant: Variant = player.get("slots", [])
	var slots: Array = (slots_variant as Array).duplicate(true) if slots_variant is Array else []
	var skill_name := _capture_sample_skill_name(root_node)
	var skill := _capture_sample_skill(root_node, skill_name)
	if skill.is_empty():
		return
	if not _slots_have_card(slots):
		if slots.is_empty():
			slots.append(skill)
		else:
			slots[0] = skill
		player["slots"] = slots
		players[selected_index] = player
		root_node.set("players", players)
	if root_node.has_method("_sync_runtime_game_screen"):
		root_node.call("_sync_runtime_game_screen", true)
	await _pump_frames(8)
	if _runtime_visible_hand_card(root_node, 0) == null:
		var hand_rack := _runtime_hand_rack(root_node)
		if hand_rack != null and hand_rack.has_method("set_cards"):
			hand_rack.call("set_cards", [_capture_hand_card_ui_data(skill)])
			await _pump_frames(4)


func _slots_have_card(slots: Array) -> bool:
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			return true
	return false


func _capture_sample_skill_name(root_node: Node) -> String:
	var market_variant: Variant = root_node.get("skill_market")
	if market_variant is Array:
		for entry_variant in market_variant:
			if entry_variant is Dictionary:
				var name := str((entry_variant as Dictionary).get("name", "")).strip_edges()
				if name != "":
					return name
			elif entry_variant is String:
				var string_name := str(entry_variant).strip_edges()
				if string_name != "":
					return string_name
	return "轨道融资1"


func _capture_sample_skill(root_node: Node, skill_name: String) -> Dictionary:
	if skill_name != "" and root_node.has_method("_make_skill"):
		var skill_variant: Variant = root_node.call("_make_skill", skill_name)
		if skill_variant is Dictionary and not (skill_variant as Dictionary).is_empty():
			return skill_variant as Dictionary
	return {
		"name": "轨道融资1",
		"kind": "cash_gain",
		"cost": 3,
		"cash": 300,
		"text": "立即获得300资金，用于城市化或补给。",
		"tags": ["经济", "续航"],
	}


func _capture_hand_card_ui_data(skill: Dictionary) -> Dictionary:
	var card := skill.duplicate(true)
	card["id"] = "capture_sample_hand_card"
	card["presentation"] = "mini_hand"
	card["detail_policy"] = "right_inspector"
	card["type"] = str(card.get("type", card.get("kind", "行动")))
	card["effect"] = str(card.get("effect", card.get("text", "用于截图验证的真实卡面。")))
	card["rank"] = str(card.get("rank", "I"))
	card["actionable"] = true
	card["drop_enabled"] = true
	card["drop_label"] = "松开出牌"
	card["actions"] = [{"id": "play_capture_sample", "label": "出牌"}]
	return card


func _stage_runtime_planet_globe(root_node: Node) -> bool:
	var map_view := _runtime_map_view(root_node)
	if map_view == null or not map_view.has_method("reset_to_planet_overview"):
		return false
	map_view.call("reset_to_planet_overview")
	return _runtime_map_projection_mode(map_view) == "globe"


func _stage_runtime_planet_local(root_node: Node) -> bool:
	var map_view := _runtime_map_view(root_node)
	if map_view == null or not map_view.has_method("zoom_to_local_projection"):
		return false
	map_view.call("zoom_to_local_projection")
	return _runtime_map_projection_mode(map_view) == "local"


func _runtime_map_projection_mode(map_view: Node) -> String:
	if map_view == null or not map_view.has_method("get_projection_debug_snapshot"):
		return ""
	var snapshot_variant: Variant = map_view.call("get_projection_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return str(snapshot.get("mode", ""))


func _runtime_map_view(root_node: Node) -> Node:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	var search_root: Node = runtime_screen if runtime_screen != null else root_node
	var map_host := search_root.find_child("MapHost", true, false)
	if map_host != null:
		var map_from_host := _find_node_with_method(map_host, "get_projection_debug_snapshot")
		if map_from_host != null:
			return map_from_host
	return _find_node_with_method(search_root, "get_projection_debug_snapshot")


func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null


func _show_runtime_drag_drop_hint(root_node: Node) -> bool:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	if runtime_screen == null:
		return false
	var hand_rack := _runtime_hand_rack(root_node)
	var map_host := runtime_screen.find_child("MapHost", true, false) as Control
	if hand_rack == null or map_host == null or not hand_rack.has_signal("card_drag_preview_started") or not hand_rack.has_signal("card_drag_preview_moved"):
		return false
	var card_data := _first_runtime_hand_card_data(hand_rack)
	if card_data.is_empty():
		card_data = {"id": "hand_0", "name": "手牌", "type": "行动", "cost": "?"}
	var off_board := Vector2(-80.0, -80.0)
	var on_board := map_host.get_global_rect().get_center()
	hand_rack.emit_signal("card_drag_preview_started", card_data, off_board)
	hand_rack.emit_signal("card_drag_preview_moved", card_data, on_board)
	return true


func _hide_runtime_drag_drop_hint(root_node: Node) -> void:
	var runtime_screen := root_node.find_child("RuntimeGameScreen", true, false)
	if runtime_screen == null:
		return
	var hand_rack := _runtime_hand_rack(root_node)
	if hand_rack != null and hand_rack.has_signal("card_drag_preview_ended"):
		hand_rack.emit_signal("card_drag_preview_ended", _first_runtime_hand_card_data(hand_rack))
	var overlay := runtime_screen.find_child("OverlayLayer", true, false)
	if overlay != null and overlay.has_method("hide_drag_preview"):
		overlay.call("hide_drag_preview")


func _first_runtime_hand_card_data(hand_rack: Node) -> Dictionary:
	for child in hand_rack.get_children():
		if child is Control and child.has_method("get_card_data"):
			var data_variant: Variant = child.call("get_card_data")
			return data_variant if data_variant is Dictionary else {}
	return {}


func _set_runtime_player_action_cooldown(root_node: Node, player_index: int, cooldown: float) -> bool:
	var players_variant: Variant = root_node.get("players")
	if not (players_variant is Array):
		return false
	var players: Array = (players_variant as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return false
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["action_cooldown"] = maxf(0.0, cooldown)
	players[player_index] = player
	root_node.set("players", players)
	return true


func _save_viewport_snapshot(file_name: String) -> void:
	await process_frame
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		var message := "viewport image is empty for %s; run this script with a visible renderer, not --headless." % file_name
		push_error("UI snapshot capture failed: %s" % message)
		_capture_failures.append(message)
		return
	var user_path := "%s/%s" % [SNAPSHOT_DIR, file_name]
	var error := image.save_png(user_path)
	if error != OK:
		var message := "failed to save %s: %s" % [user_path, error]
		push_error("UI snapshot capture failed to save %s" % message)
		_capture_failures.append(message)
		return
	_saved_paths.append(ProjectSettings.globalize_path(user_path))
